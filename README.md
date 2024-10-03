# Purity NAT Type Tester

A cross-platform app built with Flutter to detect the NAT type of the current network.

## Features

- Cross-platform (iOS, Android, Windows, macOS, Linux)
- Detects current network NAT type (Full Cone, Restricted Cone, Port Restricted Cone, Symmetric)
- Easy-to-use interface

![Screenshot_20241003_133801.png](doc%2FScreenshot_20241003_133801.png)

## Web Platform Not Supported

This app does not support web platforms due to browser limitations on using UDP over WebSockets.     
For more information:

- [Why can't I send UDP packets from a browser?](https://gafferongames.com/post/why_cant_i_send_udp_packets_from_a_browser/)
- [JavaScript WebSockets with UDP?](https://stackoverflow.com/questions/4657033/javascript-websockets-with-udp)
- [Reading from udp port in browser](https://www.codeease.net/programming/questions/reading-from-udp-port-in-browser)

## License

This project is licensed under the GPL License.

## Resources

- [家庭网络中的「NAT」到底是什么？](https://sspai.com/post/68037)
- [P2P通信原理与实现](./doc/P2P通信原理与实现.md)
- [P2P通信标准协议(一)之STUN](./doc/P2P通信标准协议(一)之STUN.md)
- [NAT的四种类型以及类型探测](./doc/NAT的四种类型以及类型探测.md)
- [talkiq/pystun3](https://github.com/talkiq/pystun3)
- [HMBSbige/NatTypeTester](https://github.com/HMBSbige/NatTypeTester)
