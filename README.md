# Tailchat

 A truly serverless, secure instant messaging app built on Tailscale's WireGuard®-based mesh network

 No message storage off device. No central servers. Just direct, encrypted communication

**Note**: Tailchat is not affiliated with, endorsed by, or sponsored by Tailscale Inc. Tailscale® and Tailnet are trademarks of Tailscale Inc.


<center>
<img src="lib/assets/images/tailchat.png" alt="Tailchat" width=128></img>
</center>

## Core Features

### 🚫 Truly Serverless

No message storage servers. No relay servers except for derp relay servers used by Tailscale®. Messages are sent directly between devices through WireGuard® mesh network, ensuring complete privacy and zero data retention.

### 🔒 Built on Tailnet

Leverages Tailscale's WireGuard®-based mesh network (Tailnet) for secure, encrypted communication. Messages travel only through your private mesh network, protected by military-grade encryption.

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

## Terms of Service and Prviacy Policy

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


