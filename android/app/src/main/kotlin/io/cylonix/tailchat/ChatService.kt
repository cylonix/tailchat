// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package io.cylonix.tailchat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationCompat.BubbleMetadata
import androidx.core.graphics.drawable.IconCompat
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import io.flutter.util.PathUtils
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.ServerSocket
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.StandardOpenOption
import java.util.concurrent.Executors
import androidx.core.app.Person as PersonCompat

data class NetworkInfo(
    @SerializedName("address") val address: String?,
    @SerializedName("hostname") val hostname: String?,
    @SerializedName("is_local") val isLocal: Boolean,
)

class ChatService :
    Service(),
    NetworkMonitorDelegate {
    private var serverSocket: ServerSocket? = null
    private val port = 50311
    private val executor = Executors.newSingleThreadExecutor()
    private var isRunning = false
    private lateinit var sharedPreferences: SharedPreferences
    private val messageBufferKey = "messageBuffer"
    private val serviceChannelID = "TailChatServiceChannel"
    private val messageChannelID = "TailChatMessageChannel"
    private val serviceNotificationID = 1
    private val messageNotificationID = 2

    private lateinit var notificationManager: NotificationManager
    private val appStateKey = "appInForeground"
    private var isAppInForeground: Boolean = true
    private lateinit var bufferFilePath: Path
    private val logger = Logger("ChatService")
    private lateinit var networkMonitor: NetworkMonitor
    private var networkInfo: List<NetworkInfo>? = null
    private var networkAvailable = false
    private val gson = Gson()

    override fun onCreate() {
        super.onCreate()
        sharedPreferences = getSharedPreferences("tailchat_prefs", Context.MODE_PRIVATE)
        notificationManager = getSystemService(NotificationManager::class.java)
        bufferFilePath = Paths.get(this.getCacheDir().absolutePath, "chat", ".tailchat_buffer.json")
        networkMonitor = NetworkMonitor(this, this)
        networkMonitor.start()

        logger.d("Service created")
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        logger.i("OnStart")
        if (!isRunning) {
            startForegroundService()
            startServer()
            isRunning = true
        }
        logger.i("Service started. Send network config.")
        sendNetworkInfo()
        sendNetworkAvailable()
        logger.i("Service started. Send buffered messages.")
        sendBufferedMessages()
        return START_STICKY // Keep the service alive even if the app crashes
    }

    override fun onDestroy() {
        logger.i("onDestroy")
        stopServer()
        isRunning = false
        networkMonitor.stop()
        logger.i("Service destroyed")
        super.onDestroy()
    }

    private fun sendNetworkInfo() {
        val json = gson.toJson(networkInfo)
        sendMessage("NETWORK:$json\n")
    }

    private fun sendNetworkAvailable() {
        val v = if (networkAvailable) "TRUE" else "FALSE"
        sendMessage("NETWORK_AVAILABLE:$v\n")
    }

    // Mark - NetworkMonitorDelegate implementation
    override fun onNetworkConfigUpdated(infos: List<NetworkInfo>) {
        logger.i("Network config updated: $infos")
        networkInfo = infos
        sendNetworkInfo()
    }

    override fun onNetworkConfigError(error: NetworkError) {
        logger.e("Network config error: $error")
        networkInfo = null
        sendNetworkInfo()
    }

    override fun onNetworkAvailabilityChanged(available: Boolean) {
        logger.i("Network availability changed: $available")
        if (networkAvailable != available) {
            networkAvailable = available
            sendNetworkAvailable()
        }
    }

    private fun getAppState(): Boolean = sharedPreferences.getBoolean(appStateKey, true)

    private fun startForegroundService() {
        createNotificationChannel()

        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent =
            PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_IMMUTABLE,
            )

        val notification =
            NotificationCompat
                .Builder(this, serviceChannelID)
                .setContentTitle("Tailchat Service")
                .setContentText("Listening for messages")
                .setSmallIcon(R.mipmap.ic_launcher_foreground)
                .setContentIntent(pendingIntent)
                .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(serviceNotificationID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING)
        } else {
            startForeground(serviceNotificationID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Service channel
            val serviceChannel =
                NotificationChannel(
                    serviceChannelID,
                    "Tailchat Service Channel",
                    NotificationManager.IMPORTANCE_DEFAULT,
                )

            // Message channel
            val messageChannel =
                NotificationChannel(
                    messageChannelID,
                    "Tailchat Messages",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    enableLights(true)
                    enableVibration(true)
                    setShowBadge(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    lightColor = android.graphics.Color.BLUE
                    description = "Tailchat notifications for new messages"
                    vibrationPattern = longArrayOf(0, 250, 250, 250)
                    setAllowBubbles(true)
                }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
            manager.createNotificationChannel(messageChannel)
        }
    }

    private fun updateNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent =
            PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_IMMUTABLE,
            )

        var bufferedMessagesCount = 0
        bufferFilePath.toFile().forEachLine { line ->
            if (line.isNotEmpty() && !line.matches(Regex("""^TEXT:[^:]+:SENDER.*"""))) {
                bufferedMessagesCount++
            }
        }

        // Service notification (foreground)
        val serviceNotification =
            NotificationCompat
                .Builder(this, serviceChannelID)
                .setContentTitle("Tailchat Service")
                .setContentText("Listening for messages")
                .setSmallIcon(R.mipmap.ic_launcher_foreground)
                .setContentIntent(pendingIntent)
                .build()

        // Message notification (with badge)
        if (bufferedMessagesCount > 0) {
            val bubbleIntent = Intent(this, MainActivity::class.java)
            val bubblePendingIntent =
                PendingIntent.getActivity(
                    this,
                    0,
                    bubbleIntent,
                    PendingIntent.FLAG_MUTABLE,
                )

            val person =
                PersonCompat
                    .Builder()
                    .setName("Tailchat")
                    .setImportant(true)
                    .build()

            val bubbleData =
                BubbleMetadata
                    .Builder(
                        bubblePendingIntent,
                        IconCompat.createWithResource(this, R.mipmap.ic_launcher_foreground),
                    ).setDesiredHeight(600)
                    .setAutoExpandBubble(true)
                    .setSuppressNotification(false)
                    .build()

            val messageNotification =
                NotificationCompat
                    .Builder(this, messageChannelID)
                    .setContentTitle("Tailchat Messages")
                    .setContentText("$bufferedMessagesCount new messages")
                    .setSmallIcon(R.mipmap.ic_launcher_foreground)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)
                    .setNumber(bufferedMessagesCount)
                    .setBadgeIconType(NotificationCompat.BADGE_ICON_SMALL)
                    .setDefaults(NotificationCompat.DEFAULT_ALL)
                    .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setBubbleMetadata(bubbleData)
                    .addPerson(person)
                    .build()

            notificationManager.notify(messageNotificationID, messageNotification)
            logger.d("Bubble notification set")
        } else {
            notificationManager.cancel(messageNotificationID)
        }

        notificationManager.notify(serviceNotificationID, serviceNotification)
    }

    private fun startServer() {
        executor.execute {
            try {
                serverSocket = ServerSocket(port)
                logger.d("Server started on port $port")

                while (isRunning) {
                    logger.d("Waiting for a connection")
                    val clientSocket = serverSocket?.accept()
                    logger.d("Get a new connection")
                    if (clientSocket != null) {
                        var remote = clientSocket.getRemoteSocketAddress()
                        logger.d("Serve the new connection from $remote in a new thread.")
                        Executors.newSingleThreadExecutor().execute {
                            logger.d("Serving the new connection from $remote")
                            handleClient(clientSocket)
                        }
                    }
                }
            } catch (e: Throwable) {
                logger.e("Error starting server: ${e::class.simpleName} ${e.message}")
            } finally {
                stopServer()
            }
        }
    }

    private fun stopServer() {
        try {
            serverSocket?.close()
            serverSocket = null
            logger.d("Server stopped")
        } catch (e: Throwable) {
            logger.e("Error stopping server: ${e::class.simpleName} ${e.message}")
        }
    }

    private fun truncateMessage(message: String): String {
        if (message.length > 256) {
            return "${message.take(256)}..."
        }
        return message
    }

    private fun handleClient(clientSocket: Socket) {
        val remote = clientSocket.getRemoteSocketAddress()
        try {
            logger.i("New connection from $remote")
            val inputStream = clientSocket.getInputStream()
            val outputStream = PrintWriter(clientSocket.getOutputStream(), true)
            val buffer = ByteArray(4096)
            var fullBuffer = ByteArray(0)
            var bytesRead: Int = -1
            while (clientSocket.isConnected && inputStream.read(buffer).also { bytesRead = it } != -1) {
                logger.d("Got input bytes $bytesRead")
                fullBuffer = fullBuffer + buffer.copyOf(bytesRead)
                while (fullBuffer.size > 0) {
                    logger.d("Full buffer size ${fullBuffer.size}")
                    val messageIndex = fullBuffer.indexOf(10); // '\n' value is 10.
                    if (messageIndex < 0) {
                        logger.d("No matching '\\n' found. continue to read.")
                        break
                    }
                    var extractedMessage = String(fullBuffer, 0, messageIndex, StandardCharsets.UTF_8)
                    fullBuffer = fullBuffer.copyOfRange(messageIndex + 1, fullBuffer.size)
                    logger.d("Received message: ${truncateMessage(extractedMessage)}")
                    val parts = extractedMessage.split(":")
                    if (parts.size < 2) {
                        throw Exception("Bad message format $extractedMessage")
                    }
                    val type = parts[0]
                    val id = parts[1]
                    when {
                        type == "CTRL" -> {
                            broadcastOrBufferMessage(extractedMessage)
                        }
                        type == "TEXT" -> {
                            broadcastOrBufferMessage(extractedMessage)
                        }
                        type == "FILE_START" -> {
                            fullBuffer = handleFileTransfer(extractedMessage, clientSocket, outputStream, fullBuffer)
                        }
                        type == "PING" -> {
                            logger.d("Receiving PING")
                            // PONG will be responded in ACK.
                        }
                        else -> {
                            if (extractedMessage.length > 20) {
                                extractedMessage = extractedMessage.substring(20)
                            }
                            throw Exception("Unrecognized message type '$type', '$extractedMessage'")
                        }
                    }
                    outputStream.println("ACK:$id:DONE")
                }
            }
        } catch (e: Throwable) {
            logger.e("Error handling client $remote: ${e::class.simpleName} ${e.message}")
        } finally {
            try {
                clientSocket.close()
            } catch (e: Throwable) {
                logger.e("Error closing socket $remote ${e::class.simpleName} ${e.message}")
            }
            logger.i("Socket with client $remote is closed")
        }
    }

    private fun handleFileTransfer(
        startMessage: String,
        clientSocket: Socket,
        outputStream: PrintWriter,
        fullBuffer: ByteArray,
    ): ByteArray {
        var file: File? = null
        var extra: ByteArray = ByteArray(0)
        val remote = clientSocket.getRemoteSocketAddress()
        val ackInterval = 500L // milliseconds
        var lastAckTime = System.currentTimeMillis()

        try {
            val parts = startMessage.substringAfter("FILE_START:").split(":")
            if (parts.size < 3) {
                throw Exception("Bad message format for FILE_START")
            }
            var id = parts[0]
            val filename = parts[1]
            val fileSize = parts[2].toLong()

            logger.d("Receiving file from $remote: name=$filename size=$fileSize")

            // val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath
            val filePath = Paths.get(PathUtils.getDataDirectory(this), "tailchat", filename)
            file = filePath.toFile()
            Files.createDirectories(filePath.parent)
            val output =
                Files.newOutputStream(
                    filePath,
                    StandardOpenOption.CREATE,
                    StandardOpenOption.TRUNCATE_EXISTING,
                    StandardOpenOption.WRITE,
                )
            val buffer = ByteArray(4096)
            var totalRead = 0L
            var bytesRead: Int = -1
            val inputStream = clientSocket.getInputStream()
            var remainingBuffer = fullBuffer
            while (totalRead < fileSize) {
                val now = System.currentTimeMillis()
                val shouldAck = now - lastAckTime >= ackInterval

                // Read from buffer passed in first if any.
                val remainingBytes = fileSize - totalRead
                if (remainingBuffer.isNotEmpty()) {
                    val bytesToRead = if (remainingBuffer.size > remainingBytes) remainingBytes.toInt() else remainingBuffer.size
                    logger.d("Read from buffer passed in $bytesToRead/${remainingBuffer.size}")
                    output.write(remainingBuffer, 0, bytesToRead)
                    totalRead += bytesToRead
                    if (remainingBuffer.size > bytesToRead) {
                        extra = remainingBuffer.copyOfRange(bytesToRead, remainingBuffer.size)
                    }
                    remainingBuffer = remainingBuffer.copyOfRange(bytesToRead, remainingBuffer.size)
                    if (totalRead >= fileSize) {
                        logger.d("Pass in buffer has all the file content we need. $totalRead/$fileSize")
                        break
                    }
                }

                // Read from input stream.
                if (totalRead < fileSize) {
                    // logger.d("Read from input stream for ${fileSize - totalRead} bytes")
                    if (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        val remainingBytes2 = fileSize - totalRead
                        val bytesToRead2 = if (bytesRead > remainingBytes2) remainingBytes2.toInt() else bytesRead
                        output.write(buffer, 0, bytesToRead2)
                        totalRead += bytesToRead2
                        if (shouldAck) {
                            outputStream.println("ACK:$id:$totalRead")
                            lastAckTime = now
                            logger.d("File received $totalRead out of $fileSize")
                        }
                        if (bytesRead > bytesToRead2) {
                            logger.d("Over-read by ${bytesRead - bytesToRead2} $totalRead/$fileSize")
                            extra = buffer.copyOfRange(bytesToRead2, bytesRead)
                            break
                        }
                    }
                }
            }

            output.close()
            logger.d("File transfer finished. Saved to $filePath")
            broadcastOrBufferMessage("FILE_END:$id:$filePath")
        } catch (e: Throwable) {
            file?.delete()
            throw Exception("Error receiving file: ${e::class.simpleName} ${e.message}")
        }
        return extra
    }

    private fun broadcastOrBufferMessage(message: String) {
        logger.d("broadcast or buffer message")
        val isFlutterRunning = getFlutterAppRunningStatus()
        if (isFlutterRunning) {
            logger.d("Flutter app is running, broadcasting message ${truncateMessage(message)}")
            sendMessage(message)
        } else {
            logger.d("Flutter app is not running, buffering message ${truncateMessage(message)}")
            appendMessageToBufferFile(message + "\n")
        }
        isAppInForeground = getAppState()
        if (!isAppInForeground) {
            logger.d("App is not in foreground, update notification")
            updateNotification()
        }
    }

    private fun appendMessageToBufferFile(message: String) {
        try {
            Files.createDirectories(bufferFilePath.parent)
            val output = Files.newOutputStream(bufferFilePath, StandardOpenOption.CREATE, StandardOpenOption.APPEND)
            output.write(message.toByteArray())
            output.close()
            logger.d("Message appended to buffer file ${truncateMessage(message)}")
        } catch (e: Throwable) {
            throw Exception("Error saving message in buffer file: ${e::class.simpleName} ${e.message}")
        }
    }

    private fun sendMessage(message: String) {
        val intent = Intent("io.cylonix.tailchat.CHAT_MESSAGE")
        intent.putExtra("message", message!!)
        sendBroadcast(intent)
    }

    private fun sendBufferedMessages() {
        logger.d("Sending buffered messages if any")
        val file = bufferFilePath.toFile()
        var count = 0
        try {
            if (file.exists()) {
                val input = BufferedReader(InputStreamReader(FileInputStream(file)))
                var message: String?
                while (input.readLine().also { message = it } != null) {
                    sendMessage(message!!)
                    logger.d("Sent buffered message: ${truncateMessage(message!!)}")
                    count++
                }
                input.close()
                logger.d("All buffered messages sent successfully")
                clearBufferFile()
                updateNotification()
            }
        } catch (e: Throwable) {
            logger.e("Error sending buffered messages: ${e::class.simpleName} ${e.message}")
        }
    }

    private fun clearBufferFile() {
        try {
            val file = bufferFilePath.toFile()
            if (file.exists()) {
                val output = FileOutputStream(file)
                output.channel.truncate(0)
                output.close()
                logger.d("Message buffer cleared")
            }
        } catch (e: Throwable) {
            logger.e("Error clearing buffer file: ${e::class.simpleName} ${e.message}")
        }
    }

    private fun getFlutterAppRunningStatus(): Boolean {
        val packageName = this.packageName
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val appProcesses = activityManager.runningAppProcesses
        if (appProcesses == null) return false

        for (process in appProcesses) {
            if (process.processName == packageName &&
                process.importance <= android.app.ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
            ) {
                return true
            }
        }
        return false
    }

    override fun onBind(intent: Intent): IBinder? = null
}
