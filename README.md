# NetPulse 0.0.1

Native iPhone network diagnostics. SwiftUI, Network.framework, Foundation.

## Features
- Live path monitoring and detection of active wired Ethernet routing
- IPv4/IPv6 addresses from getifaddrs
- DNS resolution with getaddrinfo
- TCP connectivity with NWConnection, 7-second timeout
- HTTPS connectivity check using URLSession
- Local persistent test history and shareable text report
- Native system dynamic colors, accessibility labels and SF Symbols

## Build
Requires macOS, Xcode 16 or newer, and XcodeGen (`brew install xcodegen`).
1. Run `xcodegen generate` in this directory.
2. Open `NetPulse.xcodeproj` in Xcode.
3. Select the NetPulse target > Signing & Capabilities, choose your Apple development team and a unique Bundle Identifier.
4. Select your iPhone and Run. To export an IPA, use Product > Archive > Distribute App and a valid signing method.

This ZIP is source code, not a signed IPA. It was not compiled or tested on an iPhone in this environment. iOS may choose Wi-Fi/cellular routes even with Ethernet attached. An external USB-C Ethernet adapter's compatibility depends on iPhone and adapter hardware.

## Not supported in 0.0.1
LLDP/CDP capture, physical switch/port detection, untagged VLAN ID, PoE voltage, wiremap, cable length, physical negotiated link speed, true ICMP ping, PDF export. iOS does not expose the required low-level capabilities to ordinary third-party apps through a generic Ethernet adapter.

## Branding
Name: NetPulse. Deep blue / cyan palette. Pulse-in-a-port symbol, supplied as 1024px icon. Native iOS design with grouped backgrounds and adaptive appearance.

## Build IPA using GitHub Actions and Windows
1. Extract the ZIP into a normal local folder, not OneDrive if possible.
2. With Git for Windows installed, right-click `UPLOAD_TO_GITHUB.ps1` > Run with PowerShell (or run it from a PowerShell session in that folder). Authenticate with GitHub if asked.
3. Visit https://github.com/Donacgreece/NetPulse/actions and choose the `Build unsigned IPA` run triggered by the push.
4. If it succeeds, download the `NetPulse-unsigned-IPA` artifact and extract the IPA from the artifact ZIP.
5. Sign and install the **unsigned** IPA using your existing sideloading workflow and free Apple ID. This does not remove the approximately 7-day signing expiry.

Note: GitHub Actions has NOT been run or validated yet. App compilation or sideload compatibility may require corrections.
