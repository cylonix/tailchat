// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package io.cylonix.tailchat

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class Logger(private val tag: String) {
    private val lock = ReentrantLock()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)
    private val TAG = "tailchat"

    companion object {
        private var logDir: File? = null
        private const val maxLogSize = 1024 * 1024 // 1MB
        private const val maxLogFiles = 5

        @Synchronized
        fun init(context: Context) {
            if (logDir != null) return
            logDir = File(context.getExternalFilesDir(null), "logs").apply {
                mkdirs()
            }
            rotateLogsIfNeeded()
        }

        private fun rotateLogsIfNeeded() {
            logDir?.let { dir ->
                val logs = dir.listFiles { _, name -> name.endsWith(".log") }
                    ?.sortedByDescending { it.lastModified() }
                    ?: return

                // Delete old logs if we have too many
                if (logs.size > maxLogFiles) {
                    logs.drop(maxLogFiles).forEach { it.delete() }
                }

                // Check current log size
                logs.firstOrNull()?.let { currentLog ->
                    if (currentLog.length() > maxLogSize) {
                        // Create new log file
                        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
                            .format(Date())
                        File(dir, "tailchat_$timestamp.log")
                    }
                }
            }
        }
    }

    private fun ensureInitialized() {
        check(logDir != null) { "Logger not initialized. Call Logger.init(context) first" }
    }

    fun d(message: String) {
        log("DEBUG", message)
    }

    fun i(message: String) {
        log("INFO", message)
    }

    fun e(message: String) {
        log("ERROR", message)
    }

    private fun log(level: String, message: String) {
        ensureInitialized()

        val timestamp = dateFormat.format(Date())
        val logMessage = "[$timestamp] [$tag] [$level] $message\n"

        // Log to Android system log
        val t = "$TAG: $tag"
        when (level) {
            "DEBUG" -> Log.d(t, message)
            "INFO" -> Log.i(t, message)
            "ERROR" -> Log.e(t, message)
        }

        // Log to file
        lock.withLock {
            val logFile = File(logDir, "tailchat.log")
            logFile.appendText(logMessage)
            rotateLogsIfNeeded()
        }
    }
}