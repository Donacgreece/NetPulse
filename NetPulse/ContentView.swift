import SwiftUI

private enum Palette {
    static let accent = Color(red: 0.14, green: 0.48, blue: 0.96)
    static let ink = Color(red: 0.08, green: 0.15, blue: 0.26)
}

struct ContentView: View {
    @EnvironmentObject private var engine: NetworkEngine
    @State private var showHistory = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    topBrand
                    hero
                    if engine.isScanning {
                        VStack(spacing: 12) {
                            ProgressView().tint(Palette.accent)
                            Text(engine.currentStep).font(.subheadline).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(22)
                    }
                    if let scan = engine.latest { resultPanel(scan) }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showHistory) { historySheet }
            .sheet(isPresented: $showAbout) { aboutSheet }
        }
        .tint(Palette.accent)
    }

    private var topBrand: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Palette.accent.gradient)
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title3.weight(.semibold)).foregroundStyle(.white)
            }.frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("NetPulse").font(.title2.bold()).tracking(-0.7)
                Text("Ethernet diagnostics").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath").font(.title3) }
                .accessibilityLabel("Check history")
                .padding(10)
            Button { showAbout = true } label: { Image(systemName: "info.circle").font(.title3) }
                .accessibilityLabel("About NetPulse")
                .padding(10)
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Palette.accent.opacity(0.09)).frame(width: 184, height: 184)
                Circle().stroke(Palette.accent.opacity(0.20), lineWidth: 1.5).frame(width: 145, height: 145)
                Circle().fill(Palette.accent.gradient).frame(width: 106, height: 106)
                    .shadow(color: Palette.accent.opacity(0.25), radius: 16, y: 8)
                Image(systemName: "cable.connector.horizontal")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(.white)
            }.accessibilityHidden(true)
            VStack(spacing: 7) {
                Text("Check your Ethernet port")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Connect your USB-C Ethernet adapter and tap Check to test the wired connection.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Task { await engine.runCheck() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: engine.isScanning ? "hourglass" : "waveform.path.ecg")
                    Text(engine.isScanning ? "Checking…" : "Run Check")
                }
                .font(.headline)
                .frame(maxWidth: .infinity).frame(height: 58)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Palette.accent.gradient, in: RoundedRectangle(cornerRadius: 19))
            .disabled(engine.isScanning)
            .accessibilityHint("Runs Ethernet-only TCP connectivity checks")
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
    }

    private func resultPanel(_ scan: ScanSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: scan.ethernetAvailable ? "checkmark.circle.fill" : "cable.connector.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(scan.ethernetAvailable ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(scan.ethernetAvailable ? "Ethernet detected" : "No wired Ethernet")
                        .font(.headline)
                    Text(scan.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ShareLink(item: engine.report) { Image(systemName: "square.and.arrow.up").font(.headline) }
                    .accessibilityLabel("Share check report")
            }
            if scan.ethernetAvailable {
                HStack {
                    Text("Address (best effort)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(scan.address).font(.system(.caption, design: .monospaced, weight: .medium))
                        .textSelection(.enabled)
                }
            }
            Divider()
            ForEach(scan.results) { test in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: test.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(test.success ? Color.green : Color.orange)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(test.title).font(.subheadline.weight(.semibold))
                        Text(test.detail).font(.subheadline).foregroundStyle(.secondary)
                        Text(test.note).font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                if test.id != scan.results.last?.id { Divider().padding(.leading, 30) }
            }
        }
        .padding(19)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }

    private var historySheet: some View {
        NavigationStack {
            List {
                ForEach(engine.history) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.ethernetAvailable ? "Ethernet check" : "No Ethernet")
                            .font(.headline)
                        Text("\(entry.passed)/\(entry.results.count) passed · \(entry.date.formatted())")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            }
            .overlay {
                if engine.history.isEmpty {
                    ContentUnavailableView("No checks yet", systemImage: "clock", description: Text("Your recent checks will appear here."))
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !engine.history.isEmpty { Button("Clear", role: .destructive) { engine.clearHistory() } }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { showHistory = false } }
            }
        }
    }

    private var aboutSheet: some View {
        NavigationStack {
            List {
                Section("NetPulse 0.0.2") {
                    Text("A focused one-tap wired Ethernet tester for iPhone.")
                }
                Section("What this edition measures") {
                    Text("Network.framework wired-route status, TCP connectivity forced through Ethernet, and system DNS resolution.")
                }
                Section("Hardware limits") {
                    Text("iOS does not expose physical switch identity, port, VLAN, PoE voltage, cable length or negotiated speed through a generic USB-C Ethernet dongle. Interface IP may be ambiguous when Wi-Fi is also active. Use the dedicated network path test as the authoritative result.")
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showAbout = false } } }
        }
    }
}
