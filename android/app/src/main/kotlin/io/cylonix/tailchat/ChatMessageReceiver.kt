// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package io.cylonix.tailchat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel

class ChatMessageReceiver(private val context: Context) : EventChannel.StreamHandler {
    private var TAG = "tailchat: ChatMessageReceiver"
    private val logger = Logger(TAG)
    private var eventSink: EventChannel.EventSink? = null
    private val broadcastReceiver = object: BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            logger.d("Received intent");
            val message = intent?.getStringExtra("message")
            logger.d("Received Message: $message")
            message?.let { eventSink?.success(it) }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events;
        val intentFilter = IntentFilter("io.cylonix.tailchat.CHAT_MESSAGE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(broadcastReceiver, intentFilter, ContextCompat.RECEIVER_EXPORTED);
        } else {
            context.registerReceiver(broadcastReceiver, intentFilter);
        }
        logger.d("Started listening to messages")
    }

    override fun onCancel(arguments: Any?) {
        logger.d("Stop listening to messages")
        context.unregisterReceiver(broadcastReceiver)
        eventSink = null
    }

    fun close(){
        onCancel(null)
    }
}
