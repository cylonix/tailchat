// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Network

enum DNSError: Error {
    case invalidLength
    case truncatedData
    case invalidResponse
    case outOfBounds
}

@propertyWrapper
struct Atomic<Value> {
    private var value: Value
    private let lock = NSLock()

    init(wrappedValue: Value) {
        value = wrappedValue
    }

    var wrappedValue: Value {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}

@available(macOS 10.15, iOS 13.0, *)
final class DNSResolver: @unchecked Sendable {
    private let logger = Logger(tag: "DNS")
    private let maxPacketSize = 512 // Standard DNS packet size
    private let queue = DispatchQueue(label: "io.cylonix.tailchat.dns")

    func reverseLookup(address: String, server: String = "100.100.100.100") async throws -> String {
        let connection = NWConnection(
            host: NWEndpoint.Host(server),
            port: NWEndpoint.Port(integerLiteral: 53),
            using: .udp
        )

        let result = try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<String, Error>) in
            guard let self = self else {
                continuation.resume(throwing: DNSError.invalidResponse)
                return
            }

            @Atomic var hasCompleted = false

            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self,
                      !hasCompleted else { return }
                self.queue.async {
                    switch state {
                    case .ready:
                        self.logger.d("Connection ready")
                        self.sendQuery(connection: connection, address: address) { result in
                            guard !hasCompleted else { return }
                            hasCompleted = true

                            switch result {
                            case let .success(hostname):
                                continuation.resume(returning: hostname)
                            case let .failure(error):
                                self.logger.e("Query failed: \(error)")
                                continuation.resume(throwing: error)
                            }
                        }
                    case let .failed(error):
                        guard !hasCompleted else { return }
                        hasCompleted = true
                        self.logger.e("Connection failed: \(error)")
                        continuation.resume(throwing: error)
                    case .cancelled:
                        guard !hasCompleted else { return }
                        hasCompleted = true
                        self.logger.e("Connection cancelled")
                        continuation.resume(throwing: DNSError.invalidResponse)
                    default:
                        break
                    }
                }
            }

            connection.start(queue: .global())

            // Add timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                guard !hasCompleted else { return }
                hasCompleted = true
                self.logger.e("DNS query timeout")
                continuation.resume(throwing: DNSError.invalidResponse)
            }
        }

        connection.cancel()
        return result
    }

    private func receiveResponse(
        connection: NWConnection,
        queryId: UInt16,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: maxPacketSize) { [weak self] content, _, _, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.e("Receive error: \(error)")
                completion(.failure(error))
                return
            }

            guard let data = content else {
                self.logger.e("No data received")
                completion(.failure(DNSError.invalidResponse))
                return
            }

            self.logger.d("Received DNS response: \(data.count) bytes")

            do {
                let hostname = try self.parseResponse(data: data, queryId: queryId)
                completion(.success(hostname))
            } catch {
                self.logger.e("Parse error: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func buildDNSQuery(address: String, queryId: UInt16) -> Data {
        var packet = Data()

        // Header
        packet.append(UInt16(queryId).bigEndian.data)
        packet.append(UInt16(0x0100).bigEndian.data) // Standard query
        packet.append(UInt16(1).bigEndian.data) // Questions
        packet.append(UInt16(0).bigEndian.data) // Answers
        packet.append(UInt16(0).bigEndian.data) // Authority RRs
        packet.append(UInt16(0).bigEndian.data) // Additional RRs

        // Query name in reverse DNS format
        let parts = address.split(separator: ".")
            .reversed()
            .map(String.init)

        // Add each part with length prefix
        for part in parts {
            packet.append(UInt8(part.count))
            packet.append(contentsOf: part.data(using: .ascii)!)
        }

        // Add "in-addr" and "arpa" parts
        packet.append(UInt8(7))
        packet.append("in-addr".data(using: .ascii)!)
        packet.append(UInt8(4))
        packet.append("arpa".data(using: .ascii)!)
        packet.append(UInt8(0)) // Null terminator

        // Query type (PTR) and class (IN)
        packet.append(UInt16(12).bigEndian.data) // Type PTR
        packet.append(UInt16(1).bigEndian.data) // Class IN

        logger.d("DNS query packet size: \(packet.count)")
        return packet
    }

    private func sendQuery(
        connection: NWConnection,
        address: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let queryId: UInt16 = 0x1234
        let packet = buildDNSQuery(address: address, queryId: queryId)

        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.logger.e("Send error: \(error)")
                completion(.failure(error))
                return
            }

            self.receiveResponse(connection: connection, queryId: queryId, completion: completion)
        })
    }

    private func readName(from data: Data, startingAt position: Int) throws -> (name: String, bytesRead: Int) {
        var result = ""
        var current = position
        var bytesRead = 0

        while current < data.count {
            let length = data[current]
            if length == 0 {
                bytesRead += 1
                break
            }

            // Handle compression pointer
            if (length & 0xC0) == 0xC0 {
                guard current + 1 < data.count else { throw DNSError.truncatedData }
                let offset = Int((UInt16(length & 0x3F) << 8) | UInt16(data[current + 1]))
                let (compressedName, _) = try readName(from: data, startingAt: offset)
                result += (result.isEmpty ? "" : ".") + compressedName
                bytesRead += 2
                break
            }

            current += 1
            bytesRead += 1

            guard current + Int(length) <= data.count else { throw DNSError.outOfBounds }

            if !result.isEmpty { result += "." }
            result += String(data: data[current ..< (current + Int(length))], encoding: .ascii) ?? ""

            current += Int(length)
            bytesRead += Int(length)
        }

        return (result, bytesRead)
    }

    private func parseResponse(data: Data, queryId: UInt16) throws -> String {
        logger.d("DNS Response:\n\(data.hexDump())")

        guard data.count >= 12 else { throw DNSError.invalidLength }

        // Verify response ID and flags
        let responseId = data.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self) }.bigEndian
        guard responseId == queryId else { throw DNSError.invalidResponse }

        var position = 12 // Skip header

        // Skip question section by finding null terminator
        while position < data.count, data[position] != 0 {
            position += Int(data[position]) + 1
        }
        position += 5 // Skip null terminator and QTYPE/QCLASS

        // Verify answer section start
        guard position + 2 <= data.count else { throw DNSError.truncatedData }

        logger.d("Now parsing the answer")
        // Handle compression pointer in answer
        if (data[position] & 0xC0) == 0xC0 {
            logger.d("Compression pointer found.")
            position += 2
        }
        // Read answer NAME field
        let (_, answerNameBytes) = try readName(from: data, startingAt: position)
        position += answerNameBytes

        // Skip TYPE(2), CLASS(2), TTL(4)
        position += 8

        // Get RDLENGTH
        guard position + 2 <= data.count else { throw DNSError.truncatedData }
        logger.d("length [\(data[position])][\(data[position + 1])]")
        let rdLength = Int(UInt16(data[position]) << 8 | UInt16(data[position + 1]))
        logger.d("Data length=\(rdLength)")
        position += 2

        guard position + rdLength <= data.count else { throw DNSError.truncatedData }
        logger.d("Start looking at the hostname labels \(position)")
        // Read hostname labels
        var result = ""
        var current = position
        let endPosition = position + rdLength

        while current < endPosition {
            let labelLength = Int(data[current])
            if labelLength == 0 { break }
            logger.d("Label length: \(labelLength)")
            current += 1
            if current + labelLength > endPosition { throw DNSError.outOfBounds }

            if !result.isEmpty { result += "." }
            result += String(data: data[current ..< (current + labelLength)], encoding: .ascii) ?? ""
            logger.d("Result: \(result)")
            current += labelLength
        }

        if result.isEmpty {
            throw DNSError.invalidResponse
        }
        return result
    }
}

private extension UInt16 {
    var data: Data {
        var value = self
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}

extension Data {
    func hexDump() -> String {
        var result = "Packet size: \(count) bytes\n"
        let hexString = map { String(format: "%02x", $0) }
        let asciiString = map { (0x20 ... 0x7E).contains($0) ? String(Character(UnicodeScalar($0))) : "." }

        for i in stride(from: 0, to: count, by: 16) {
            // Offset
            result += String(format: "%04x  ", i)

            // Hex values
            for j in 0 ..< 16 {
                if i + j < count {
                    result += hexString[i + j] + " "
                } else {
                    result += "   "
                }
                if j == 7 { result += " " }
            }

            // ASCII values
            result += " |"
            for j in 0 ..< 16 {
                if i + j < count {
                    result += asciiString[i + j]
                } else {
                    result += " "
                }
            }
            result += "|\n"
        }
        return result
    }
}
