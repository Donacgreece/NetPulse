# NetPulse 0.0.5

Native SwiftUI iOS diagnostic app, iOS 17+. Includes wired interface checks, secure SNMPv3 SHA-256/AES-128 credentials in Keychain and optional SNMP queries to explicitly known management hosts.

## Important technical constraint

A standard iPhone app using an ordinary USB-C Ethernet dongle cannot promise direct switch identity, physical port or VLAN from credentials alone. SNMPv3 requires a destination address. LLDP/CDP raw Ethernet frame access requires an Apple-restricted capability. This version deliberately **does not scan subnets or fabricate switch/port results**.

## Build

Run the GitHub Actions `Build unsigned IPA` workflow. Download the artifact and sign the IPA with your own Apple ID. This package has been statically checked but has **not** been compiled on Xcode in the current environment or tested on actual switches.

## Notes

Switch port matching when a known SNMP host is reachable is best effort using ARP and forwarding tables, not a substitute for physical link testing. Wiremap, TDR and PoE voltage require specialized hardware. Make sure use of SNMP and management access is authorized.
