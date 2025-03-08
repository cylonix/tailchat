// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package io.cylonix.tailchat

import android.Manifest
import android.app.AlertDialog
import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val tag = "MainActivity"
    private val channel = "io.cylonix.tailchat/chat_service"
    private val eventChannel = "io.cylonix.tailchat/chat_messages"
    private lateinit var messageReceiver: ChatMessageReceiver
    private lateinit var sharedPreferences: SharedPreferences
    private val appStateKey = "appInForeground"
    private var chatServiceStarted = false
    private val logger = Logger(tag)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        messageReceiver = ChatMessageReceiver(this)
        sharedPreferences = getSharedPreferences("tailchat_prefs", Context.MODE_PRIVATE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        logger.i("Starting ChatService.")
                        startChatService()
                        chatServiceStarted = true
                        result.success("Service Started.")
                    }
                    "stopService" -> {
                        logger.i("Stopping ChatService.")
                        stopChatService()
                        chatServiceStarted = false
                        result.success("Service Stopped.")
                    }
                    "logs" -> {
                        logger.i("Fetching logs.")
                        val logs = getChatServiceLogs()
                        result.success(logs)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannel)
            .setStreamHandler(messageReceiver)
    }

    private fun getChatServiceLogs(): String {
        val file = logger.logFile()
        return if (file.exists()) {
            file.readText()
        } else {
            "Log file not found."
        }
    }

    override fun onResume() {
        logger.d("MainActivity Resumed")
        super.onResume()
        setAppState(true)
        startChatService() // To receive buffered messages.
    }

    override fun onPause() {
        logger.d("MainActivity Paused")
        super.onPause()
        setAppState(false)
    }

    override fun onDestroy() {
        super.onDestroy()
        setAppState(false)
        messageReceiver.close()
        logger.d("Destroying Activity and Closing Receiver")
    }

    private var hasNotificationPermission = false
    private val permissionLauncher =
        registerForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { isGranted: Boolean ->
            hasNotificationPermission = isGranted
            if (isGranted) {
                logger.d("Notification permission granted")
            } else {
                logger.d("Notification permission denied")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Logger.init(this)
        checkAndRequestPermission()
    }

    private fun checkAndRequestPermission() {
        when {
            // First check: Is permission already granted?
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED -> {
                hasNotificationPermission = true
                logger.d("Notification permission already granted")
            }
            // Second check: Should we show permission rationale?
            shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) -> {
                logger.d("User previously denied, showing rationale")
                AlertDialog.Builder(this)
                    .setTitle("Notification Permission Required")
                    .setMessage(
                        "You previously denied this permission. Tailchat needs notifications " +
                        "to alert you about new messages even when the app is in background. " +
                        "Without this permission, you might miss important messages."
                    )
                    .setPositiveButton("Try Again") { dialog: DialogInterface, _: Int ->
                        dialog.dismiss()
                        permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    }
                    .setNegativeButton("Not Now") { dialog: DialogInterface, _: Int ->
                        dialog.dismiss()
                        logger.d("User denied notification permission again")
                        // Optionally guide user to settings if they need to enable manually
                        showSettingsDialog()
                    }
                    .create()
                    .show()
            }
            // Third case: First time request or "Don't ask again" was checked
            else -> {
                logger.d("First time permission request")
                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    private fun showSettingsDialog() {
        AlertDialog.Builder(this)
            .setTitle("Permission Required")
            .setMessage(
                "Notifications are required for Tailchat to work properly. " +
                "Please enable them in Settings."
            )
            .setPositiveButton("Open Settings") { dialog: DialogInterface, _: Int ->
                dialog.dismiss()
                // Open app settings
                startActivity(Intent().apply {
                    action = android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = android.net.Uri.fromParts("package", packageName, null)
                })
            }
            .setNegativeButton("Cancel") { dialog: DialogInterface, _: Int ->
                dialog.dismiss()
            }
            .create()
            .show()
    }

    private fun startChatService() {
        val serviceIntent = Intent(this, ChatService::class.java)
        startService(serviceIntent)
    }

    private fun stopChatService() {
        val serviceIntent = Intent(this, ChatService::class.java)
        stopService(serviceIntent)
    }

    private fun setAppState(appInForeground: Boolean) {
        val editor = sharedPreferences.edit()
        editor.putBoolean(appStateKey, appInForeground)
        editor.apply()
    }
}
