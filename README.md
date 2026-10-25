# NetPulse 0.0.2

Native SwiftUI one-tap wired Ethernet diagnostic app for iPhone 15 and later with a compatible USB-C Ethernet adapter.

## What Check actually does

1. Determines if iOS reports an available **wired Ethernet path** via `NWPathMonitor(requiredInterfaceType: .wiredEthernet)`.
2. Reads an IPv4 address for the specific interface name reported by the wired path, when the OS exposes one.
3. If a wired path exists, tests TCP to `1.1.1.1:443` and `8.8.8.8:443` with `NWParameters.requiredInterfaceType = .wiredEthernet` to prevent cellular/Wi-Fi fallback.
4. Checks system DNS for `example.com` (this DNS lookup **is not constrained to Ethernet**).
5. Presents test results, exports a shareable text report, and stores up to 30 checks locally.

TCP timings measure the TCP handshake, not ICMP ping, physical Ethernet speed or throughput. Firewalls can prevent a successful TCP result even on functioning LANs. iOS does not expose physical switch port, LLDP/CDP, PoE measurement, cable length or VLAN configuration through generic adapter APIs.

## How to build an unsigned IPA

`GitHub Actions > Build unsigned IPA > Run workflow`, or push to main. Download **NetPulse-unsigned-IPA** from the successful run's Artifacts. Extract the ZIP for `NetPulse-0.0.2-unsigned.ipa`. Sign via your own sideloading tool and Apple ID.

This project is **not** verified on a physical phone or compiled locally. The Actions build is the macOS compilation test.

## Local development

Install Xcode and XcodeGen on macOS, run `xcodegen generate` then open `NetPulse.xcodeproj`. Deployment target iOS 17. Code signing is disabled only in the Actions build.

## Files

- `NetPulse/ContentView.swift`: redesigned SwiftUI interface
- `NetPulse/NetworkEngine.swift`: wired-path monitor and tests
- `NetPulse/Assets.xcassets`: new app branding
- `.github/workflows/build-ipa.yml`: automatic unsigned IPA build
- `UPLOAD_TO_GITHUB.ps1`: Windows upload script
