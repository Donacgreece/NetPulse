import Foundation
import Network
import Darwin

struct ProbeResult: Identifiable, Codable {
    var id = UUID()
    let title: String
    let detail: String
    let success: Bool
    let note: String
}

struct ScanSnapshot: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let ethernetAvailable: Bool
    let address: String
    let results: [ProbeResult]
    var passed: Int { results.filter(\.success).count }
}

@MainActor final class NetworkEngine: ObservableObject {
    @Published private(set) var ethernetAvailable = false
    @Published private(set) var ethernetInterfaceName: String?
    @Published private(set) var isScanning = false
    @Published private(set) var currentStep = ""
    @Published private(set) var latest: ScanSnapshot?
    @Published private(set) var history: [ScanSnapshot] = []

    private let ethernetMonitor = NWPathMonitor(requiredInterfaceType: .wiredEthernet)
    private let monitorQueue = DispatchQueue(label: "netpulse.ethernet.monitor")
    private let historyKey = "netpulse.scan.history.v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([ScanSnapshot].self, from: data) {
            history = saved
            latest = saved.first
        }
        ethernetMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.ethernetAvailable = path.status == .satisfied
                self?.ethernetInterfaceName = path.availableInterfaces.first(where: { $0.type == .wiredEthernet })?.name
            }
        }
        ethernetMonitor.start(queue: monitorQueue)
    }

    deinit { ethernetMonitor.cancel() }

    private func ethernetIPv4() -> String? {
        guard let ethernetInterfaceName else { return nil }
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let start = head else { return nil }
        defer { freeifaddrs(head) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = start
        while let pointer = cursor {
            let item = pointer.pointee
            if let addr = item.ifa_addr, Int32(addr.pointee.sa_family) == AF_INET {
                let name = String(cString: item.ifa_name)
                // iOS uses en interfaces for both wired and Wi-Fi. Only show an address
                // when an actual wired Ethernet route has been reported by Network.framework.
                if name == ethernetInterfaceName {
                    var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(MemoryLayout<sockaddr_in>.size), &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let value = String(cString: buffer)
                        if !value.hasPrefix("169.254.") { return value }
                    }
                }
            }
            cursor = item.ifa_next
        }
        return nil
    }

    func runCheck() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false; currentStep = "" }

        currentStep = "Checking USB-C Ethernet…"
        // Monitor can receive its first update asynchronously.
        try? await Task.sleep(nanoseconds: 350_000_000)
        let plugged = ethernetAvailable
        var results: [ProbeResult] = []
        let address = plugged ? (ethernetIPv4() ?? "Not exposed") : "Unavailable"
        if !plugged {
            results.append(ProbeResult(title: "Ethernet link", detail: "No active wired route", success: false, note: "Connect a compatible USB-C Ethernet adapter and active LAN cable. Wi-Fi and cellular are not tested."))
        } else {
            results.append(ProbeResult(title: "Ethernet link", detail: "Wired path available", success: true, note: "Verified through Network.framework's wired Ethernet path monitor."))
            currentStep = "Testing LAN connection…"
            let local = await tcpConnect(host: "1.1.1.1", port: 443, timeout: 6)
            results.append(ProbeResult(title: "Ethernet TCP reachability", detail: local.message, success: local.ok, note: "Attempts a TCP connection to 1.1.1.1:443 forced through wired Ethernet. This is not ICMP ping."))
            currentStep = "Checking alternative destination…"
            let backup = await tcpConnect(host: "8.8.8.8", port: 443, timeout: 6)
            results.append(ProbeResult(title: "Second route test", detail: backup.message, success: backup.ok, note: "Attempts TCP to 8.8.8.8:443 through wired Ethernet. Firewalls may block this test."))
            currentStep = "Resolving DNS…"
            let dns = await resolve("example.com")
            results.append(ProbeResult(title: "DNS resolution", detail: dns.message, success: dns.ok, note: "System DNS resolution. iOS may use another interface or private DNS for this request."))
        }
        let snapshot = ScanSnapshot(date: Date(), ethernetAvailable: plugged, address: address, results: results)
        latest = snapshot
        history.insert(snapshot, at: 0)
        history = Array(history.prefix(30))
        if let data = try? JSONEncoder().encode(history) { UserDefaults.standard.set(data, forKey: historyKey) }
    }

    func clearHistory() {
        history = []
        latest = nil
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    var report: String {
        guard let scan = latest else { return "NetPulse 0.0.2 | No check yet" }
        let lines = scan.results.map { "\($0.success ? "PASS" : "CHECK") | \($0.title): \($0.detail)\n\($0.note)" }.joined(separator: "\n\n")
        return "NetPulse 0.0.2 | Wired network check\nDate: \(scan.date.formatted())\nEthernet available: \(scan.ethernetAvailable)\nInterface address (best effort): \(scan.address)\n\n\(lines)\n\nNote: switch name, port, VLAN, link speed and PoE require switch management or dedicated hardware."
    }

    private func tcpConnect(host: String, port: UInt16, timeout: TimeInterval) async -> (ok: Bool, message: String) {
        await withCheckedContinuation { continuation in
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .wiredEthernet
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: parameters)
            let queue = DispatchQueue(label: "netpulse.check.\(UUID().uuidString)")
            let gate = CompletionGate()
            let start = Date()
            func complete(_ ok: Bool, _ detail: String) {
                guard gate.markCompleted() else { return }
                connection.stateUpdateHandler = nil
                connection.cancel()
                continuation.resume(returning: (ok, detail))
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: complete(true, String(format: "Connected in %.0f ms", Date().timeIntervalSince(start) * 1000))
                case .failed(let error): complete(false, error.localizedDescription)
                case .cancelled: complete(false, "Cancelled")
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { complete(false, "No response within \(Int(timeout))s") }
        }
    }

    private func resolve(_ hostname: String) async -> (ok: Bool, message: String) {
        await Task.detached(priority: .userInitiated) {
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var answer: UnsafeMutablePointer<addrinfo>?
            let error = getaddrinfo(hostname, nil, &hints, &answer)
            guard error == 0, let first = answer else { return (false, "DNS failed (\(error))") }
            defer { freeaddrinfo(first) }
            var names: [String] = []
            var item: UnsafeMutablePointer<addrinfo>? = first
            while let current = item {
                if let address = current.pointee.ai_addr {
                    var result = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(address, current.pointee.ai_addrlen, &result, socklen_t(result.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let text = String(cString: result)
                        if !names.contains(text) { names.append(text) }
                    }
                }
                item = current.pointee.ai_next
            }
            return (true, names.prefix(2).joined(separator: ", "))
        }.value
    }
}

private final class CompletionGate {
    private let lock = NSLock()
    private var completed = false
    func markCompleted() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if completed { return false }
        completed = true
        return true
    }
}
