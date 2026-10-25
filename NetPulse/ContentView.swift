import SwiftUI

struct ContentView: View {
    @StateObject private var inspector = PortInspector()
    @StateObject private var settings = SecureSettings()
    @State private var showingSettings = false

    private let blue = Color(red: 0.16, green: 0.45, blue: 0.93)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(blue.gradient)
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .font(.title2).foregroundStyle(.white)
                        }.frame(width: 50, height: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NetPulse").font(.title2.bold())
                            Text("Switch & Port Inspector").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { showingSettings = true } label: {
                            Image(systemName:"gearshape").font(.title3).padding(10)
                        }.accessibilityLabel("SNMPv3 settings")
                    }
                    VStack(spacing: 16) {
                        Image(systemName: "cable.connector.horizontal")
                            .font(.system(size: 48)).foregroundStyle(blue)
                            .frame(height: 80)
                        Text("Inspect your Ethernet port").font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Connect USB-C Ethernet, then inspect accessible managed switches using SNMPv3.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            Circle().fill(inspector.ethernet ? Color.green : .orange).frame(width: 8,height: 8)
                            Text(inspector.ethernet ? "Ethernet detected" : "Ethernet not detected")
                        }.font(.subheadline.weight(.medium))
                        Button {
                            Task { await inspector.inspect(settings.profile) }
                        } label: {
                            Label(inspector.scanning ? "Inspecting…" : "Check Port",
                                  systemImage: inspector.scanning ? "hourglass" : "waveform.path.ecg")
                                .font(.headline).frame(maxWidth: .infinity).frame(height: 56)
                        }
                        .buttonStyle(.plain).foregroundStyle(.white)
                        .background(blue.gradient,in:RoundedRectangle(cornerRadius:18))
                        .disabled(inspector.scanning)
                    }
                    .padding(24)
                    .frame(maxWidth:.infinity)
                    .background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:26))

                    if inspector.scanning {
                        ProgressView().frame(maxWidth:.infinity)
                    }
                    if inspector.scanning || inspector.completed {
                        HStack {
                            Image(systemName:"info.circle").foregroundStyle(blue)
                            Text(inspector.status).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if inspector.completed {
                        HStack {
                            Text("Ethernet IP").foregroundStyle(.secondary)
                            Spacer()
                            Text(inspector.localIP).font(.system(.subheadline,design:.monospaced))
                        }.padding(18)
                         .background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:18))
                    }
                    ForEach(inspector.switches) { sw in
                        VStack(alignment:.leading,spacing:15) {
                            HStack {
                                Image(systemName:"network").foregroundStyle(blue)
                                Text(sw.name).font(.title3.bold())
                                Spacer()
                            }
                            Text(sw.address).font(.caption.monospaced()).foregroundStyle(.secondary)
                            line("Port",sw.interfaceName)
                            line("VLAN",sw.vlan)
                            line("Link speed",sw.speed)
                            line("Port status",sw.status)
                            line("Errors",sw.errors)
                            Divider()
                            Label(sw.confidence,systemImage: sw.portIndex == nil ? "exclamationmark.circle" : "checkmark.circle")
                                .font(.caption).foregroundStyle(sw.portIndex == nil ? .orange : .green)
                            ShareLink(item: report(sw)) {
                                Label("Share results",systemImage:"square.and.arrow.up")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        .padding(20)
                        .background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:23))
                    }
                    if inspector.completed && inspector.switches.isEmpty {
                        ContentUnavailableView("No switches discovered",systemImage:"network.slash",
                            description:Text("Check SNMPv3 credentials, management network reachability, configured hosts and SNMP access rules."))
                    }
                    Text("v0.0.3 · SNMPv3 SHA-256 / AES-128. Switch port and VLAN are shown only when SNMP tables allow a defensible match. Cable wiremap and TDR require dedicated hardware.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }.padding(20)
            }
            .background(Color(uiColor:.systemGroupedBackground))
            .toolbar(.hidden,for:.navigationBar)
            .sheet(isPresented:$showingSettings) { settingsSheet }
        }.tint(blue)
    }
    private func line(_ title:String,_ value:String) -> some View {
        HStack(alignment:.firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength:16)
            Text(value).multilineTextAlignment(.trailing).fontWeight(.medium).textSelection(.enabled)
        }.font(.subheadline)
    }
    private func report(_ s: SwitchReading) -> String {
        "NetPulse 0.0.3\nSwitch: \\(s.name) (\\(s.address))\nPort: \\(s.interfaceName)\nVLAN: \\(s.vlan)\nSpeed: \\(s.speed)\nStatus: \\(s.status)\nErrors: \\(s.errors)\nMatch: \\(s.confidence)"
    }
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("SNMPv3 username",text:$settings.username)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Authentication password (SHA-256)",text:$settings.authPassword)
                    SecureField("Privacy password (AES)",text:$settings.privacyPassword)
                } header: { Text("SNMPv3 authPriv") } footer: {
                    Text("Uses SHA-256 authentication and AES-128 privacy. Credentials are stored only in iOS Keychain on this device.")
                }
                Section {
                    TextEditor(text:$settings.manualHosts).frame(minHeight:90)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Discover first 64 addresses of local /24",isOn:$settings.scanSubnet)
                } header: { Text("Switch management addresses") } footer: {
                    Text("Enter IPs separated by commas, spaces or new lines. Automatic discovery is best effort and assumes /24. Only use on networks where scanning is authorized. An unreachable management VLAN cannot be discovered through SNMP.")
                }
                Section("Limits") {
                    Text("Physical port identification depends on bridge forwarding and ARP tables. Discovery may find a switch but not your port. VLAN PVID is reported only where supported; the VLAN of the iPhone itself cannot be inferred reliably in every topology.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Network access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button("Save") { settings.save(); showingSettings = false }.bold()
                }
                ToolbarItem(placement:.topBarLeading) {
                    Button("Cancel") { showingSettings = false; settings.load() }
                }
            }
        }
    }
}
