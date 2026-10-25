import SwiftUI

@main
struct NetPulseApp: App {
    @StateObject private var engine = NetworkEngine()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(engine)
        }
    }
}
