// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package io.cylonix.tailchat

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "io.cylonix.tailchat/chat_service"
    private val EVENT_CHANNEL = "io.cylonix.tailchat/chat_messages"
    private lateinit var messageReceiver: ChatMessageReceiver
    private lateinit var sharedPreferences: SharedPreferences
    private val appStateKey = "appInForeground"
    private var chatServiceStarted = false
    private val logger = Logger(TAG)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        messageReceiver = ChatMessageReceiver(this);
        sharedPreferences = getSharedPreferences("tailchat_prefs", Context.MODE_PRIVATE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).
            setMethodCallHandler { call, result ->
            when(call.method) {
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
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).
            setStreamHandler(messageReceiver)
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
        setAppState(true);
        startChatService() // To receive buffered messages.
    }

    override fun onPause() {
        logger.d("MainActivity Paused")
        super.onPause()
        setAppState(false);
    }

    override fun onDestroy() {
        super.onDestroy()
        setAppState(false);
        messageReceiver.close()
        logger.d("Destroying Activity and Closing Receiver")
    }

    private var hasNotificationPermission = false
    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
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
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED -> {
                hasNotificationPermission = true
                logger.d("Notification permission already granted")
            }
            shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) -> {
                // Show an explanation to the user why the permission is needed
                logger.d("Showing permission rationale")
                // Show a dialog here and then request the permission again
            }
            else -> {
                // Directly request for permission
                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    private fun startChatService() {
        val serviceIntent = Intent(this, ChatService::class.java)
        startService(serviceIntent)
    }
    private fun stopChatService() {
        val serviceIntent = Intent(this, ChatService::class.java)
        stopService(serviceIntent)
    }
    private fun setAppState(appInForeground: Boolean){
        val editor = sharedPreferences.edit();
        editor.putBoolean(appStateKey, appInForeground)
        editor.apply();
    }
}

