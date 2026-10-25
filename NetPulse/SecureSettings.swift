import Foundation
import Security

@MainActor final class SecureSettings: ObservableObject {
    @Published var username = ""
    @Published var authPassword = ""
    @Published var privacyPassword = ""
    @Published var manualHosts = ""
    @Published var scanSubnet = false
    init() { load() }
    private let service = "app.netpulse.snmpv3"
    private func read(_ key: String) -> String {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service,
                kSecAttrAccount as String:key,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var data: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&data) == errSecSuccess,
              let bytes = data as? Data else { return "" }
        return String(data: bytes,encoding:.utf8) ?? ""
    }
    private func write(_ key: String, _ text: String) {
        let q: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:key]
        SecItemDelete(q as CFDictionary)
        guard !text.isEmpty, let bytes = text.data(using:.utf8) else { return }
        var add = q
        add[kSecValueData as String] = bytes
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary,nil)
    }
    func load() {
        username = read("username"); authPassword = read("auth")
        privacyPassword = read("privacy"); manualHosts = read("hosts")
        scanSubnet = read("scanSubnet") == "1"
    }
    func save() {
        write("username",username.trimmingCharacters(in:.whitespacesAndNewlines))
        write("auth",authPassword); write("privacy",privacyPassword)
        write("hosts",manualHosts); write("scanSubnet",scanSubnet ? "1":"0")
    }
    var profile: SNMPProfile { SNMPProfile(username: username, authPassword:authPassword,privacyPassword:privacyPassword,manualHosts:manualHosts,scanSubnet:scanSubnet) }
}
