// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Network
import NetworkExtension
import SystemConfiguration

struct Device: Codable {
    let address: String
    let hostname: String
    let interface: String?
    let isLocal: Bool
    let isPhysical: Bool

    enum CodingKeys: String, CodingKey {
        case address
        case hostname
        case interface
        case isLocal = "is_local"
        case isPhysical = "is_physical"
    }
}

protocol NetworkMonitorDelegate: AnyObject {
    func didUpdateNetworkConfig(devices: [Device])
    func didFailToUpdateNetwork(error: Error)
}

/// Network related errors
enum NetworkError: Error {
    case interfaceNotFound
    case addressNotFound
    case dnsResolutionFailed
    case invalidAddress
}

class NetworkMonitor {
    private var monitor: NWPathMonitor?
    private let logger = Logger(tag: "NetworkMonitor")
    private weak var delegate: NetworkMonitorDelegate?
    var onNetworkStatusChange: ((Bool) -> Void)?

    private enum CGNATRange {
        static let start = "100.64.0.0"
        static let end = "100.127.255.255"
    }

    private enum BackoffConfig {
        static let maxAttempts = 3
        static let initialDelay: TimeInterval = 1.0
        static let maxDelay: TimeInterval = 5.0
    }

    init(delegate: NetworkMonitorDelegate) {
        self.delegate = delegate
    }

    func start() {
        logger.i("Start")
        startPathMonitor()
    }

    private func startPathMonitor() {
        monitor?.cancel()
        monitor = nil

        logger.i("Starting path monitor")

        // Only monitor VPN interfaces
        monitor = NWPathMonitor(requiredInterfaceType: .other)
        monitor?.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor?.start(queue: queue)
        logger.i("Started")
    }

    private func getRoutes() throws -> [(address: String, interface: String?, isLocal: Bool, isPhysical: Bool)] {
        var routes: [(address: String, interface: String?, isLocal: Bool, isPhysical: Bool)] = []

        // Get interface addresses using getifaddrs
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else {
            throw NetworkError.interfaceNotFound
        }
        defer { freeifaddrs(addrs) }

        var addr = addrs
        while addr != nil {
            let name = String(cString: addr!.pointee.ifa_name)

            // Check for en0 (WiFi), en1 (Ethernet), pdp_ip0 (Cellular)
            if ["en0", "en1", "pdp_ip0"].contains(name) {
                var interface: String? = nil
                if name == "en0" {
                    interface = "WiFi"
                } else if name == "en1" {
                    interface = "Ethernet"
                } else if name == "pdp_ip0" {
                    interface = "Cellular"
                }
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if let addr = addr!.pointee.ifa_addr {
                    let family = addr.pointee.sa_family

                    // Only handle IPv4 and IPv6
                    if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                        if getnameinfo(addr,
                                       socklen_t(addr.pointee.sa_len),
                                       &hostname, socklen_t(hostname.count),
                                       nil, 0,
                                       NI_NUMERICHOST) == 0
                        {
                            let ip = String(cString: hostname)
                            // Skip loopback addresses
                            if !ip.hasPrefix("127."), !ip.hasPrefix("::1") {
                                logger.d("Found interface \(name) with IP: \(ip)")
                                routes.append((ip, interface, true, true))
                            }
                        }
                    }
                }
            }
            addr = addr!.pointee.ifa_next
        }
        // Monitor all interfaces including VPN
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // Look for VPN interfaces (utun)
            for interface in path.availableInterfaces where interface.type == .other {
                if interface.name.hasPrefix("utun") {
                    self.logger.d("Found VPN interface: \(interface.name)")

                    // Get interface addresses using getifaddrs
                    var addrs: UnsafeMutablePointer<ifaddrs>?
                    guard getifaddrs(&addrs) == 0 else {
                        continue
                    }
                    defer { freeifaddrs(addrs) }

                    var addr = addrs
                    while addr != nil {
                        let name = String(cString: addr!.pointee.ifa_name)
                        if name == interface.name {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if let addr = addr!.pointee.ifa_addr {
                                if getnameinfo(addr,
                                               socklen_t(addr.pointee.sa_len),
                                               &hostname, socklen_t(hostname.count),
                                               nil, 0,
                                               NI_NUMERICHOST) == 0
                                {
                                    let ip = String(cString: hostname)
                                    if self.isCGNATAddress(ip) {
                                        routes.append((ip, "vpn", true, false))
                                    }
                                }
                            }
                        }
                        addr = addr!.pointee.ifa_next
                    }
                }
            }
            monitor.cancel()
            semaphore.signal()
        }

        monitor.start(queue: .global())
        semaphore.wait()

        return routes
    }

    private func findCGNATAddresses() async throws -> [Device] {
        var devices: [Device] = []

        if let routes = try? getRoutes() {
            logger.d("Routes: \(routes)")
            for route in routes {
                logger.d("Address found: \(route.address), isLocal: \(route.isLocal)")
                if route.isPhysical {
                    devices.append(Device(
                        address: route.address,
                        hostname: "",
                        interface: route.interface,
                        isLocal: true,
                        isPhysical: true
                    ))
                    continue
                }
                if let hostname = try? await resolveDNS(for: route.address) {
                    devices.append(Device(
                        address: route.address,
                        hostname: hostname,
                        interface: route.interface,
                        isLocal: route.isLocal,
                        isPhysical: false
                    ))
                }
            }
        }

        return devices
    }

    func stop() {
        if let monitor = monitor {
            logger.i("Stopped Ref count=\(CFGetRetainCount(monitor))")
            monitor.cancel()
            self.monitor = nil
        }
        logger.i("Stopped.")
    }

    deinit {
        logger.i("Deinit. I am gone.")
    }

    private func handlePathUpdate(_ path: Network.NWPath) {
        logger.i("Network path \(path) changed")
        onNetworkStatusChange?(path.status == .satisfied)
        handlePathOrRouteUpdate()
    }

    private func handlePathOrRouteUpdate() {
        Task {
            do {
                let allDevices = try await findCGNATAddresses()
                if !allDevices.isEmpty {
                    delegate?.didUpdateNetworkConfig(devices: allDevices)
                } else {
                    throw NetworkError.addressNotFound
                }
            } catch {
                delegate?.didFailToUpdateNetwork(error: error)
            }
        }
    }

    #if os(macOS)
        private func shell(_ command: String) -> String {
            let task = Process()
            let pipe = Pipe()

            task.standardOutput = pipe
            task.arguments = ["-c", command]
            task.launchPath = "/bin/bash"
            task.launch()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        }

        private func parseRoutes(_ output: String) -> [String] {
            return output.components(separatedBy: .newlines)
                .compactMap { line -> String? in
                    let components = line.components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    guard components.count >= 2 else { return nil }
                    let destination = components[0]
                    if destination.contains(".") {
                        return destination
                    }
                    return nil
                }
        }
    #endif
    private func isCGNATAddress(_ address: String) -> Bool {
        guard let ip = IPv4Address(address),
              let start = IPv4Address(CGNATRange.start),
              let end = IPv4Address(CGNATRange.end)
        else {
            return false
        }

        let ipValue = ip.rawValue.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let startValue = start.rawValue.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let endValue = end.rawValue.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

        return ipValue >= startValue && ipValue <= endValue
    }

    private let dnsResolver = DNSResolver()
    private func resolveDNS(for address: String) async throws -> String {
        do {
            return try await dnsResolver.reverseLookup(address: address)
        } catch {
            logger.e("DNS resolution failed: \(error)")
            throw NetworkError.dnsResolutionFailed
        }
    }
}
