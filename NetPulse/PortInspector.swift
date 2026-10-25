import Foundation
import Network
import Darwin

@MainActor final class PortInspector: ObservableObject {
    @Published var scanning = false
    @Published var status = "Ready to inspect"
    @Published var localIP = "Not detected"
    @Published var ethernet = false
    @Published var switches: [SwitchReading] = []
    @Published var completed = false
    private let worker = SNMPService()
    private let monitor = NWPathMonitor(requiredInterfaceType:.wiredEthernet)
    private let queue = DispatchQueue(label:"netpulse.inspector.path")
    private var interfaceName: String?
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.ethernet = path.status == .satisfied
                self?.interfaceName = path.availableInterfaces.first(where:{$0.type == .wiredEthernet})?.name
            }
        }
        monitor.start(queue:queue)
    }
    deinit { monitor.cancel() }
    private func interfaceIP() -> String? {
        guard let wanted = interfaceName else { return nil }
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let start = head else { return nil }
        defer { freeifaddrs(head) }
        var p: UnsafeMutablePointer<ifaddrs>? = start
        while let item = p {
            let a = item.pointee
            if String(cString:a.ifa_name) == wanted, let addr = a.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var buf = [CChar](repeating:0,count:Int(NI_MAXHOST))
                if getnameinfo(addr,socklen_t(MemoryLayout<sockaddr_in>.size),&buf,socklen_t(buf.count),nil,0,NI_NUMERICHOST) == 0 {
                    return String(cString:buf)
                }
            }
            p = a.ifa_next
        }
        return nil
    }
    func inspect(_ profile: SNMPProfile) async {
        guard !scanning else { return }
        scanning = true; completed = false; switches = []; localIP = "Not detected"
        defer { scanning = false; completed = true }
        guard ethernet else { status = "No active wired Ethernet route. Check the USB-C adapter and cable."; return }
        guard !profile.username.isEmpty, !profile.authPassword.isEmpty, !profile.privacyPassword.isEmpty else {
            status = "Configure SNMPv3 credentials first"; return
        }
        localIP = interfaceIP() ?? "Not detected"
        // Deliberately do not scan the local subnet. SNMPv3 is a management
        // protocol, not a link-neighbor discovery protocol on iOS.
        let hosts = Array(Set(profile.manualHosts.split(whereSeparator: {
            $0 == "," || $0 == "\n" || $0 == " "
        }).map(String.init).filter { parseIPv4($0) != nil })).sorted()
        guard !hosts.isEmpty else {
            status = "No switch address is known. iOS cannot read LLDP/CDP frames with standard app privileges. SNMP credentials alone cannot identify the cable's far end."
            return
        }
        for (idx, host) in hosts.enumerated() {
            status = "Querying \(idx+1) of \(hosts.count): \(host)"
            if let item = await worker.inspect(host:host,localIP:localIP == "Not detected" ? "":localIP,profile:profile) {
                switches.append(item)
            }
        }
        status = switches.isEmpty ? "No SNMPv3 response from configured switch address(es). Confirm UDP 161 access, routing and SHA-256/AES-128 compatibility." : "Found \(switches.count) switch(es)"
    }
    private func parseIPv4(_ ip: String) -> [UInt8]? {
        let parts = ip.split(separator:".")
        guard parts.count == 4 else { return nil }
        let n = parts.compactMap { UInt8($0) }
        return n.count == 4 ? n : nil
    }
}
