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
                            Text("Ethernet & Switch Diagnostics").font(.caption).foregroundStyle(.secondary)
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
                        Text("Check Ethernet connection").font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Check the wired connection. SNMPv3 can inspect a switch only when its management address is reachable.")
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
                        ContentUnavailableView("Switch not identified",systemImage:"network.slash",
                            description:Text("The iPhone cannot identify the physical switch using SNMP credentials alone. A known management address or special Ethernet frame access is required."))
                    }
                    Text("v0.0.5 · SNMPv3 SHA-256 / AES-128. Switch port and VLAN are shown only when SNMP tables allow a defensible match. Cable wiremap and TDR require dedicated hardware.")
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
        "NetPulse 0.0.5\nSwitch: \\(s.name) (\\(s.address))\nPort: \\(s.interfaceName)\nVLAN: \\(s.vlan)\nSpeed: \\(s.speed)\nStatus: \\(s.status)\nErrors: \\(s.errors)\nMatch: \\(s.confidence)"
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
                    Text("No subnet scanning. Enter only approved switch management addresses for optional SNMP diagnostics.").font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Switch management addresses") } footer: {
                    Text("SNMPv3 credentials do not locate the cable's opposite end. Address information is needed for optional management queries. No scanning is performed.")
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
