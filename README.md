# Tailchat

 A truly serverless, secure instant messaging app built on WireGuard®-based mesh network provided by Cylonix or Tailscale.

 No message storage off device. No central message servers. Just direct, end-to-end encrypted communication

**Note**: Tailchat is not affiliated with, endorsed by, or sponsored by Tailscale Inc. Tailscale® and Tailnet are trademarks of Tailscale Inc.

[Install Tailchat and Join Tailchat beta](https://cylonix.io/web/view/tailchat/download.html)

![Tailchat](lib/assets/images/tailchat.png)

## Core Features

### 🚫 Truly Serverless

No message storage servers. No relay servers except for derp relay servers used by Tailscale®. Messages are sent directly between devices through WireGuard® mesh network, ensuring complete privacy and zero data retention.

### Special notes about iOS

For iOS devices, iOS suspends apps that go into the background. The peer will need to use other communication channel
to request to reconnect when the iOS user switches away from tailchat. Since switching apps can be a very frequent event, sender will automatically request to reconnect with push notifications. A per-device generated UUID and the push notification token assigned to the iOS device are saved in the push notification server. The UUID and the push notification token cannot be used to identify a device name or user. Chat message is never sent to the push notification server. For details, please refer to the link to the push notification server below:

[Push notification server code](https://github.com/cylonix/tailchat/blob/main/pnserver)

For Cylonix users, Cylonix which is the open source version of the Tailscale, provides on-device listening of the receiving port on the ios packet tunnel Network Extension to mitigate the background suspension issue. For details please refer to the
code below: [Cylonix tailchat assist code](https://github.com/cylonix/wireguard-apple/tree/cylonix2/Sources/WireGuardKitGo/tailchat)

### 🔒 Built on WireGuard Mesh Network

Leverages WireGuard®-based mesh network for secure, encrypted communication. Messages travel only through your private mesh network, protected by encryption.

### 💻 100% Open Source

Every line of code is open source and available for review. Verify the security yourself, contribute to development, or modify it for your needs.

## How It Works

### Direct Device-to-Device Communication

- Messages travel directly between devices through WireGuard® tunnels
- No message storage or forwarding servers
- Messages exist only on sender and receiver devices
- Automatic peer discovery within your mesh network for some platforms. For other platforms, you can manually add peers.

## Perfect For

### 🛡️ Privacy-Focused Users

Those who want complete control over their messages with zero data retention

### 🏢 Security-Critical Teams

Organizations requiring secure, auditable communication channels

### 👥 Private Networks

Groups wanting to maintain their own secure communication infrastructure

## Terms of Service and Privacy Policy

- [Terms of Service](https://cylonix.io/web/view/tailchat/terms.html)
- [Privacy Policy](https://cylonix.io/web/view/tailchat/privacy_policy.html)

## Contact

For questions or support, contact us at [contact@cylonix.io](mailto:contact@cylonix.io)

## License

[BSD-3](./LICENSE)

## Getting Started

### Generate locale files

``` bash
make generate
```

### Build android apk or aab

``` bash
make apk
make aab
```

### Build debian package

``` bash
make deb
```

### Build macos or ios package

Please follow flutter macos and ios app building instructions with xcode.

- <https://docs.flutter.dev/deployment/macos>

- <https://docs.flutter.dev/deployment/ios>
