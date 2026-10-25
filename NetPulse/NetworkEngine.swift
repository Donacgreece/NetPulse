import Foundation
import Network
import Darwin

struct InterfaceInfo: Identifiable {
    let id: String
    let name: String
    let addresses: [String]
    var ethernet: Bool { name.hasPrefix("en") }
}

struct TestRecord: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let name: String
    let result: String
    let passed: Bool
}

@MainActor final class NetworkEngine: ObservableObject {
    @Published var interfaces: [InterfaceInfo] = []
    @Published var pathDescription = "Checking…"
    @Published var connectionType = "Unknown"
    @Published var isOnline = false
    @Published var records: [TestRecord] = []
    @Published var isRunning = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "netpulse.path")
    private let storageKey = "netpulse.records.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey), let saved = try? JSONDecoder().decode([TestRecord].self, from: data) { records = saved }
        refreshInterfaces()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnline = path.status == .satisfied
                self?.pathDescription = path.status == .satisfied ? "Network available" : "No network connection"
                self?.connectionType = path.usesInterfaceType(.wiredEthernet) ? "Ethernet" : path.usesInterfaceType(.wifi) ? "Wi-Fi" : path.usesInterfaceType(.cellular) ? "Cellular" : "Other / Disconnected"
                self?.refreshInterfaces()
            }
        }
        monitor.start(queue: queue)
    }

    func refreshInterfaces() {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return }
        defer { freeifaddrs(pointer) }
        var grouped: [String: [String]] = [:]
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let node = current {
            let entry = node.pointee
            if let address = entry.ifa_addr {
                let family = Int32(address.pointee.sa_family)
                if family == AF_INET || family == AF_INET6 {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let length = family == AF_INET ? socklen_t(MemoryLayout<sockaddr_in>.size) : socklen_t(MemoryLayout<sockaddr_in6>.size)
                    if getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let name = String(cString: entry.ifa_name)
                        grouped[name, default: []].append(String(cString: host))
                    }
                }
            }
            current = entry.ifa_next
        }
        interfaces = grouped.map { InterfaceInfo(id: $0.key, name: $0.key, addresses: $0.value.sorted()) }.sorted { $0.name < $1.name }
    }

    private func add(_ name: String, _ result: String, _ passed: Bool) {
        records.insert(TestRecord(date: Date(), name: name, result: result, passed: passed), at: 0)
        if records.count > 150 { records = Array(records.prefix(150)) }
        if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: storageKey) }
    }

    func clearHistory() { records = []; UserDefaults.standard.removeObject(forKey: storageKey) }

    func dnsLookup(_ hostname: String) async {
        let host = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { add("DNS Lookup", "Enter a hostname", false); return }
        isRunning = true
        let result: String = await Task.detached(priority: .userInitiated) {
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var res: UnsafeMutablePointer<addrinfo>?
            let code = getaddrinfo(host, nil, &hints, &res)
            guard code == 0, let first = res else { return "DNS failed (\(code))" }
            defer { freeaddrinfo(res) }
            var found = Set<String>()
            var current: UnsafeMutablePointer<addrinfo>? = first
            while let node = current {
                if let addr = node.pointee.ai_addr {
                    var output = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, node.pointee.ai_addrlen, &output, socklen_t(output.count), nil, 0, NI_NUMERICHOST) == 0 {
                        found.insert(String(cString: output))
                    }
                }
                current = node.pointee.ai_next
            }
            return found.sorted().joined(separator: ", ")
        }.value
        add("DNS: \(host)", result, !result.hasPrefix("DNS failed"))
        isRunning = false
    }

    func tcpTest(host: String, port: UInt16) async {
        let target = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, port > 0, let nwPort = NWEndpoint.Port(rawValue: port) else { add("TCP Test", "Invalid host or port", false); return }
        isRunning = true
        let started = Date()
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, String), Never>) in
            let connection = NWConnection(host: NWEndpoint.Host(target), port: nwPort, using: .tcp)
            let q = DispatchQueue(label: "netpulse.tcp.test")
            let lock = NSLock()
            var finished = false
            func finish(_ success: Bool, _ message: String) {
                lock.lock(); defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                connection.stateUpdateHandler = nil
                connection.cancel()
                continuation.resume(returning: (success, message))
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true, String(format: "Connected in %.0f ms", Date().timeIntervalSince(started) * 1000))
                case .failed(let error): finish(false, error.localizedDescription)
                case .cancelled: finish(false, "Connection cancelled")
                default: break
                }
            }
            connection.start(queue: q)
            q.asyncAfter(deadline: .now() + 7) { finish(false, "Timed out after 7 seconds") }
        }
        add("TCP: \(target):\(port)", result.1, result.0)
        isRunning = false
    }

    func httpTest() async {
        isRunning = true
        let start = Date()
        do {
            var request = URLRequest(url: URL(string: "https://www.apple.com/library/test/success.html")!)
            request.timeoutInterval = 10
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            add("HTTPS Connectivity", "HTTP \(status), \(Int(Date().timeIntervalSince(start) * 1000)) ms", (200...299).contains(status))
        } catch { add("HTTPS Connectivity", error.localizedDescription, false) }
        isRunning = false
    }

    var report: String {
        let header = "NetPulse 0.0.1 | Network Report\nGenerated: \(Date().formatted())\nConnection: \(connectionType)\nStatus: \(pathDescription)\n\nINTERFACES\n"
        let details = interfaces.map { "\($0.name): \($0.addresses.joined(separator: ", "))" }.joined(separator: "\n")
        let history = records.map { "\($0.date.formatted()) | \($0.passed ? "PASS" : "FAIL") | \($0.name) | \($0.result)" }.joined(separator: "\n")
        return header + details + "\n\nTEST HISTORY\n" + history
    }
}
