# Mac-to-Mac LAN experiment

Branch: `feat/lan-direct`, based on `nmt3325/openairdisplay`.

This first experiment separates blocked Bonjour discovery from blocked
client-to-client TCP. Automatic AWDL-to-LAN migration is not implemented yet.

## Try it on eduroam

1. Open OpenAirDisplay Receiver on the Mac that will act as a display.
2. Find its Wi-Fi IP in the receiver's **Direct connection** section, or in
   System Settings → Wi-Fi → Details → TCP/IP when using an older receiver.
3. Disconnect any existing session to that receiver first.
4. On the sending Mac, enter that numeric address and port `9000` under
   **Direct connection**, then click **Connect over LAN**.
5. The established session should show **WiFi (LAN)**. This explicit connection
   disables peer-to-peer support and does not depend on Bonjour. A normal
   discovered-device connection continues to allow AWDL.

To test the listening port before granting capture permission, run this on
the sending Mac, substituting the receiver's actual IP:

```sh
nc -vz -G 3 10.2.3.4 9000
```

A TCP success proves reachability, not video performance. A failure alone
does not prove eduroam isolation: also check that the receiver is open,
the IP is current, Local Network access is granted, and the receiver's macOS
firewall allows the app. Compare with the same two Macs on another LAN.

## Build

```sh
xcodegen generate
xcodebuild -project OpenSidecar.xcodeproj -scheme OpenSidecarMac \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
xcodebuild -project OpenSidecar.xcodeproj -scheme OpenSidecarMacReceiver \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
./run.sh
```

Keep the existing Debug bundle identifiers and signing requirements stable.
Do not replace installed release apps or deploy to another Mac without choosing
the intended receiver. No device deployment or eduroam streaming result is
implied by compilation or unit tests.

## Next experiment

Once direct LAN video works, use the existing AWDL session to obtain the Mac
receiver's `hello.addrs`, probe infrastructure Wi-Fi with peer-to-peer disabled,
verify the candidate receiver identity before handing over, and retain AWDL
when probing fails. The existing cable upgrade machinery is the starting point;
it currently prohibits Wi-Fi and must not be treated as LAN migration already.
