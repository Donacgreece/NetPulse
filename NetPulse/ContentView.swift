import SwiftUI

private enum Brand {
    static let blue = Color(red: 0.13, green: 0.42, blue: 0.94)
}

struct ContentView: View {
    @EnvironmentObject private var engine: NetworkEngine
    @State private var host = "1.1.1.1"
    @State private var port = "443"
    @State private var dnsHost = "apple.com"
    var body: some View {
        TabView {
            dashboard.tabItem { Label("Overview", systemImage: "square.grid.2x2") }
            diagnostics.tabItem { Label("Diagnostics", systemImage: "waveform.path.ecg") }
            history.tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .tint(Brand.blue)
    }

    private var dashboard: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: "cable.connector").font(.title2).foregroundStyle(.white)
                            .frame(width: 54, height: 54).background(Brand.blue.gradient, in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Network status").font(.headline)
                            Text(engine.pathDescription).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: engine.isOnline ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(engine.isOnline ? .green : .orange).font(.title2)
                    }.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                    HStack(spacing: 12) {
                        metric("Connection", engine.connectionType, "network")
                        metric("Interfaces", "\(engine.interfaces.count)", "point.3.connected.trianglepath.dotted")
                    }
                    Text("Network interfaces").font(.title3.bold())
                    if engine.interfaces.isEmpty { ContentUnavailableView("No IP interfaces", systemImage: "network.slash", description: Text("Connect a network adapter and try again.")) }
                    ForEach(engine.interfaces) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: item.ethernet ? "cable.connector" : "network")
                                    .foregroundStyle(Brand.blue)
                                Text(item.name).font(.headline)
                                Spacer()
                                if item.ethernet { Text("Ethernet family").font(.caption2).foregroundStyle(.secondary) }
                            }
                            ForEach(item.addresses, id: \.self) { address in
                                Text(address).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    Text("Interface names alone do not prove that an external Ethernet adapter is active. Check the connection type above.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("NetPulse")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { engine.refreshInterfaces() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh interfaces") } }
        }
    }

    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Brand.blue)
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var diagnostics: some View {
        NavigationStack {
            Form {
                Section("Internet connectivity") {
                    Text("Tests HTTPS connectivity to an Apple endpoint. This is not an ICMP ping.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Run HTTPS test") { Task { await engine.httpTest() } }
                }
                Section("DNS lookup") {
                    TextField("Hostname", text: $dnsHost).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Resolve hostname") { Task { await engine.dnsLookup(dnsHost) } }
                }
                Section("TCP port test") {
                    TextField("Host or IP", text: $host).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Port (1–65535)", text: $port).keyboardType(.numberPad)
                    Button("Test TCP connection") { Task { await engine.tcpTest(host: host, port: UInt16(port) ?? 0) } }
                }
                if let latest = engine.records.first {
                    Section("Latest result") {
                        Label(latest.passed ? "Passed" : "Failed", systemImage: latest.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(latest.passed ? .green : .red)
                        Text(latest.name).font(.headline)
                        Text(latest.result).textSelection(.enabled)
                    }
                }
                Section { Text("Tests use the network route selected by iOS. A connected Ethernet adapter does not guarantee that traffic uses Ethernet if other interfaces are available.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Diagnostics")
            .overlay { if engine.isRunning { ProgressView("Running test…").padding(22).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .disabled(engine.isRunning)
        }
    }

    private var history: some View {
        NavigationStack {
            List {
                ForEach(engine.records) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: item.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(item.passed ? .green : .red)
                            Text(item.name).font(.headline)
                        }
                        Text(item.result).font(.subheadline).textSelection(.enabled)
                        Text(item.date.formatted()).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }
            }
            .overlay { if engine.records.isEmpty { ContentUnavailableView("No tests yet", systemImage: "clock", description: Text("Run a diagnostic to save its result.")) } }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !engine.records.isEmpty { Button("Clear", role: .destructive) { engine.clearHistory() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: engine.report) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share network report")
                }
            }
        }
    }
}
