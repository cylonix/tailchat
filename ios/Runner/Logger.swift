// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import os.log

public class Logger {
    private let tag: String
    private let fileManager = FileManager.default
    private let logQueue = DispatchQueue(label: "io.cylonix.tailchat.logger")
    private let maxLogFiles = 5
    private let maxFileSize: UInt64 = 1024 * 1024 // 1MB

    private lazy var logFileURL: URL = {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("tailchat.log")
    }()

    private lazy var osLog: OSLog = .init(subsystem: "io.cylonix.tailchat", category: tag)

    init(tag: String) {
        self.tag = tag
        rotateLogFileIfNeeded()
    }

    func d(_ message: String) {
        log(level: "DEBUG", message: message)
    }

    func i(_ message: String) {
        log(level: "INFO", message: message)
    }

    func w(_ message: String) {
        log(level: "WARN", message: message)
    }

    func e(_ message: String) {
        log(level: "ERROR", message: message)
    }

    private func log(level: String, message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(tag)] [\(level)] \(message)\n"

        // Log to console using os_log
        os_log("%{public}@", log: osLog, type: .default, logMessage)

        // Log to file with timestamp and tag
        logQueue.async {
            self.writeToFile(logMessage)
            self.rotateLogFileIfNeeded()
        }
    }

    private func writeToFile(_ message: String) {
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }

        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(message.data(using: .utf8) ?? Data())
            try? handle.close()
        }
    }

    private func rotateLogFileIfNeeded() {
        let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path)
        let fileSize = attributes?[.size] as? UInt64
        guard let fileSize = fileSize else {
            os_log("%{public}@", log: osLog, type: .default, "[LOGGER] [ERROR] File size unknown.")
            return
        }
        if fileSize < maxFileSize {
            return
        }
        os_log("%{public}@", log: osLog, type: .default, "[LOGGER] Rotate log file \(fileSize) \(maxFileSize)")

        // Rotate existing log files
        for i in (1 ... maxLogFiles - 1).reversed() {
            let oldLog = logFileURL.deletingPathExtension().appendingPathExtension("\(i).log")
            let newLog = logFileURL.deletingPathExtension().appendingPathExtension("\(i + 1).log")
            try? fileManager.moveItem(at: oldLog, to: newLog)
        }

        // Move current log to .1.log
        let firstRotatedLog = logFileURL.deletingPathExtension().appendingPathExtension("1.log")
        try? fileManager.moveItem(at: logFileURL, to: firstRotatedLog)

        // Create new empty log file
        fileManager.createFile(atPath: logFileURL.path, contents: nil)
    }

    static func opt(_ a: Any?) -> String {
        return a.map { String(describing: $0) } ?? "nil"
    }

    func getLogFilePath() -> String {
        return logFileURL.path
    }
}
