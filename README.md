# NetPulse 0.0.4 | iOS SNMPv3 beta

Source build for native SwiftUI iPhone network diagnostics with SHA-256 authentication and AES-128 privacy via SwiftSnmpKit. Compatible with iOS 17+ (subject to successful Xcode build).

## Fixes from build failures
- SwiftSnmpKit local package manifest patched to iOS 13 (main app targets iOS 17).
- Swift async nil-coalescing autoclosure compile error fixed in SNMPService.swift.
- Version bumped to 0.0.4 and artifact output renamed.
- Build uses Xcode 16.4 macOS runner and outputs unsigned IPA to GitHub Actions artifacts.

## SNMPv3 settings
Open Settings (gear icon), enter username, authentication password (SHA-256), privacy password (AES-128), and any switch management IPs, then tap Save. Values are stored in the iOS Keychain (ThisDeviceOnly), and reloaded on subsequent launches. Do not enter credentials in source files or GitHub.

## Important limitations
- Without known reachable SNMP management addresses, discovering switches on another VLAN is not generally possible. The optional first-64-host subnet search may miss relevant devices.
- Switch identity/port/VLAN depend on exposed SNMP tables and the ARP-to-MAC-to-FDB mapping. A switch may respond without enabling exact physical port matching.
- No physical PoE voltage, cable wiremap, or TDR tests without dedicated hardware.
- This package is source code, not an already-built IPA. A passing Xcode build and real-hardware SNMP tests are still required.

## Upload and build
Extract zip, run `UPLOAD_TO_GITHUB.ps1` from the project directory, then view Actions in `Donacgreece/NetPulse`. After the workflow succeeds, download and unzip `NetPulse-unsigned-IPA` artifact. Sign IPA with your own Apple ID in your chosen sideloading tool.
