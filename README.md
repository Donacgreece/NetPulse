# NetPulse 0.0.3

Native SwiftUI wired switch inspector using SNMPv3 `authPriv` (SHA-256 + AES-128).

## Usage
1. Connect the iPhone to a managed wired network using a USB-C Ethernet adapter.
2. Settings: enter SNMPv3 username, **authentication password**, and **privacy password**. Secrets remain in iOS Keychain (`WhenUnlockedThisDeviceOnly`).
3. Add management IPv4 addresses (strongly recommended) or opt into limited /24 discovery of the first 64 addresses.
4. Tap **Check Port**. The app issues real SNMPv3 queries to responding devices. Unavailable fields are explicitly marked unavailable.

## How port association works
The app tries to retrieve the iPhone Ethernet IP from iOS. It then searches the responding device's SNMP ARP table for the adapter MAC, the bridge FDB for that MAC, and the bridge-port to ifIndex mapping. This only works when a device exposes the relevant tables and the same MAC is found locally. Many access switches do not have an ARP entry for their attached clients, so port identification often fails. This is a limitation of a generic SNMP-only implementation, not of the UI.

## Limitations
- SNMP agent must be enabled, reachable and permit relevant OIDs. SNMPv3 credentials are insufficient if management access is filtered.
- Automated discovery is a bounded best-effort scan, not universal switch discovery. The first 64 addresses of a guessed local /24 are tested only when enabled. A management network outside that range requires manual switch IPs or routing information.
- The observed VLAN PVID is not guaranteed to equal every tagged/untagged VLAN used by a port. Only displayed after a port match.
- Ethernet negotiated speed is reported from IF-MIB/IF-X-MIB and may be nominal rather than PHY-negotiated, depending on switch.
- Input error counters are cumulative; no wiremap, TDR, PoE voltage measurement without special hardware.
- No credentials are printed or saved in reports, logs or Git source.
- Project not yet verified by an Xcode build or physical iPhone test. Review SNMP dependency versions and security policies before production usage.

## Build
Push to GitHub and use Actions -> Build unsigned IPA. Download the `NetPulse-unsigned-IPA` artifact after a successful build. Extract `.ipa` and sign with your chosen sideloading tool. Workflow produces **unsigned** IPA only.

## Dependency
[SwiftSnmpKit](https://github.com/darrellroot/SwiftSnmpKit) (SNMPv3 GET/GET-NEXT with SHA-256 and AES), pulled by XcodeGen as a Swift package. Review dependency maintenance and licensing before public distribution.
