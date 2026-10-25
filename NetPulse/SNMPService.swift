import Foundation
import SwiftSnmpKit

struct SwitchReading: Identifiable, Codable {
    var id: String { address }
    let address: String
    var name: String = "Unknown switch"
    var model: String = "Unavailable"
    var interfaceName: String = "Not identified"
    var portIndex: Int? = nil
    var vlan: String = "Not advertised"
    var speed: String = "Not available"
    var status: String = "Unknown"
    var errors: String = "Not available"
    var confidence: String = "Switch discovered; port not confirmed"
}

struct SNMPProfile: Codable {
    var username: String = ""
    var authPassword: String = ""
    var privacyPassword: String = ""
    var manualHosts: String = ""
    var scanSubnet: Bool = false
}

actor SNMPService {
    private var sender: SnmpSender? { SnmpSender.shared }
    private let sysName = "1.3.6.1.2.1.1.5.0"
    private let sysDescr = "1.3.6.1.2.1.1.1.0"
    private let arpTable = "1.3.6.1.2.1.4.22.1.2"
    private let bridgeFDB = "1.3.6.1.2.1.17.4.3.1.2"
    private let bridgeIfIndex = "1.3.6.1.2.1.17.1.4.1.2"

    private func get(_ host: String, _ oid: String, _ profile: SNMPProfile, next: Bool = false) async -> SnmpVariableBinding? {
        guard let sender else { return nil }
        let result = await sender.send(host: host, userName: profile.username,
            pduType: next ? .getNextRequest : .getRequest, oid: oid,
            authenticationType: .sha256, authPassword: profile.authPassword,
            privPassword: profile.privacyPassword)
        if case .success(let binding) = result { return binding }
        return nil
    }

    private func value(_ binding: SnmpVariableBinding?) -> String? {
        guard let binding else { return nil }
        switch binding.value {
        case .octetString(let data):
            if let string = String(data: data, encoding: .utf8), !string.isEmpty, !string.contains("\u{FFFD}") { return string.trimmingCharacters(in: .controlCharacters) }
            return data.map { String(format: "%02x", $0) }.joined(separator: ":")
        case .integer(let v): return String(v)
        case .gauge32(let v): return String(v)
        case .counter32(let v): return String(v)
        case .counter64(let v): return String(v)
        default: return nil
        }
    }
    private func numeric(_ host: String, _ oid: String, _ profile: SNMPProfile) async -> Int? {
        guard let v = value(await get(host,oid,profile)) else { return nil }
        return Int(v)
    }
    private func walk(_ host: String, _ prefix: String, _ profile: SNMPProfile, max: Int = 128) async -> [SnmpVariableBinding] {
        var out: [SnmpVariableBinding] = []
        var oid = prefix
        for _ in 0..<max {
            guard let row = await get(host,oid,profile,next:true) else { break }
            let actual = row.oid.description
            guard actual.hasPrefix(prefix + "."), actual != oid else { break }
            out.append(row)
            oid = actual
        }
        return out
    }
    private func macBytes(_ binding: SnmpVariableBinding) -> [Int]? {
        if case .octetString(let data) = binding.value { return data.map { Int($0) } }
        return nil
    }
    func inspect(host: String, localIP: String, profile: SNMPProfile) async -> SwitchReading? {
        guard let sn = await get(host,sysName,profile) else { return nil }
        var reading = SwitchReading(address: host)
        reading.name = value(sn) ?? host
        reading.model = value(await get(host,sysDescr,profile)) ?? "Unavailable"
        // Find adapter MAC by looking up its IP in a switch/router ARP table.
        // This may fail for L2 access switches with no routed interface in the client's subnet.
        var adapterMAC: [Int]?
        if !localIP.isEmpty {
            for row in await walk(host,arpTable,profile,max:256) {
                if row.oid.description.hasSuffix("." + localIP.replacingOccurrences(of: ".", with: ".")) {
                    adapterMAC = macBytes(row)
                    break
                }
            }
        }
        if let mac = adapterMAC, mac.count == 6 {
            let suffix = mac.map { String($0) }.joined(separator: ".")
            if let bridgePort = await numeric(host,"\(bridgeFDB).\(suffix)",profile), bridgePort > 0,
               let ifIndex = await numeric(host,"\(bridgeIfIndex).\(bridgePort)",profile) {
                reading.portIndex = ifIndex
                let highCapacityName = value(await get(host,"1.3.6.1.2.1.31.1.1.1.1.\(ifIndex)",profile))
                let basicName: String?
                if highCapacityName == nil {
                    basicName = value(await get(host,"1.3.6.1.2.1.2.2.1.2.\(ifIndex)",profile))
                } else {
                    basicName = nil
                }
                reading.interfaceName = highCapacityName ?? basicName ?? "ifIndex \(ifIndex)"
                reading.confidence = "Port matched via ARP and bridge FDB"
                if let speed = await numeric(host,"1.3.6.1.2.1.31.1.1.1.15.\(ifIndex)",profile), speed > 0 {
                    reading.speed = "\(speed) Mbps (interface reported)"
                } else if let bps = await numeric(host,"1.3.6.1.2.1.2.2.1.5.\(ifIndex)",profile), bps > 0 {
                    reading.speed = "\(bps / 1_000_000) Mbps (interface reported)"
                }
                if let state = await numeric(host,"1.3.6.1.2.1.2.2.1.8.\(ifIndex)",profile) {
                    reading.status = state == 1 ? "Up" : "Down (\(state))"
                }
                if let errs = await numeric(host,"1.3.6.1.2.1.2.2.1.14.\(ifIndex)",profile) {
                    reading.errors = "\(errs) input errors (cumulative)"
                }
                if let pvid = await numeric(host,"1.3.6.1.2.1.17.7.1.4.5.1.1.\(bridgePort)",profile) {
                    reading.vlan = "\(pvid) (reported PVID)"
                }
            }
        }
        return reading
    }
}
