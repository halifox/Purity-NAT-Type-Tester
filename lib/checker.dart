import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:purity_nat_type_tester/hex.dart';

///
/// STUN（NAT 会话穿越实用工具）属性
/// 每个属性都有一个唯一的十六进制标识符，用于 STUN 消息中实现不同功能。
///

const String MAPPED_ADDRESS = '0001'; // 映射地址，表示请求来自的地址（映射的 IP 和端口）。
const String RESPONSE_ADDRESS = '0002'; // 指定应将响应发送到的地址（用于罕见情况）。
const String CHANGE_REQUEST = '0003'; // 指示客户端是否希望更改通信的 IP 和/或端口。
const String SOURCE_ADDRESS = '0004'; // 表示接收到 STUN 请求的原始源地址。
const String CHANGED_ADDRESS = '0005'; // 提供备用地址，如果服务器更改了响应的 IP 或端口时使用。
const String USERNAME = '0006'; // 包含用于消息认证的用户名（可选）。
const String PASSWORD = '0007'; // 包含用于消息认证的密码（可选）。
const String MESSAGE_INTEGRITY = '0008'; // 包含 HMAC 用于确保消息完整性。
const String ERROR_CODE = '0009'; // 指定 STUN 消息的错误代码，提供错误详情。
const String UNKNOWN_ATTRIBUTE = '000A'; // 列出服务器未知或无法理解的属性。
const String REFLECTED_FROM = '000B'; // 表示响应的反射源（在旧版本中使用）。
const String XOR_ONLY = '0021'; // 指示所有后续属性将使用 XOR 映射地址以增强安全性。
const String XOR_MAPPED_ADDRESS = '8020'; // 提供与魔术 cookie 异或的映射地址，以避免拦截。
const String SERVER_NAME = '8022'; // 表示 STUN 服务器的名称，通常用于信息展示。
const String SECONDARY_ADDRESS = '8050'; // 非标准扩展，提供备用地址（通常用于自定义实现）。

// 6 字节源地址长度（通常用来描述 IP 地址和端口）。
const String IP_ADDRESS_AND_PORT_LENGTH_6_BYTES = "00000006";
// 2 字节源地址长度（通常用于描述端口信息）。
const String PORT_LENGTH_2_BYTES = "00000002";

///
/// STUN 消息的类型
/// 每种消息类型都有一个唯一的十六进制标识符，用于区分不同的 STUN 请求和响应类型。
///

const String BIND_REQUEST_MSG = '0001'; // 绑定请求消息，用于请求服务器绑定客户端的 IP 和端口。
const String BIND_RESPONSE_MSG = '0101'; // 绑定响应消息，服务器对绑定请求的正常响应。
const String BIND_ERROR_RESPONSE_MSG = '0111'; // 绑定错误响应消息，服务器对绑定请求出错的响应。
const String SHARED_SECRET_REQUEST_MSG = '0002'; // 共享密钥请求消息，请求服务器生成共享密钥。
const String SHARED_SECRET_RESPONSE_MSG = '0102'; // 共享密钥响应消息，服务器返回共享密钥的正常响应。
const String SHARED_SECRET_ERROR_RESPONSE_MSG = '0112'; // 共享密钥错误响应消息，服务器对共享密钥请求出错的响应。

final Map<String, Completer<NATTestResult>> completers = {};

///
/// NAT 类型和错误信息
/// 这些字符串用于描述不同类型的 NAT 以及在测试过程中遇到的错误。
///
enum NATType {
  unknown,
  blocked, // 表示网络被阻止，无法通过 NAT。
  openInternet, // 表示开放的互联网，无需 NAT。
  fullCone, // 表示全锥形 NAT，允许所有外部主机通过相同的端口。
  symmetricUDPFirewall, // 表示对称 UDP 防火墙，只允许特定的外部主机与特定端口通信。
  restrictNAT, // 表示限制性 NAT，允许通信但有限制。
  restrictPortNAT, // 表示限制端口的 NAT，仅允许通过特定端口进行通信。
  symmetricNAT, // 表示对称 NAT，每个请求都会使用不同的端口，增加追踪难度。
  changedAddressError, // 测试 Changed IP 和端口时遇到的错误。
}

class NATTestResult {
  NATType type;
  bool resp;
  String externalIp;
  int externalPort;
  String sourceIp;
  int sourcePort;
  String changedIp;
  int changedPort;

  NATTestResult(this.type, this.resp, this.externalIp, this.externalPort, this.sourceIp, this.sourcePort, this.changedIp, this.changedPort);

  static final NATTestResult UNKNOWN = NATTestResult(NATType.unknown, false, "", 0, "", 0, "", 0);

  @override
  String toString() {
    return 'NATTestResult{type: $type, resp: $resp, externalIp: $externalIp, externalPort: $externalPort, sourceIp: $sourceIp, sourcePort: $sourcePort, changedIp: $changedIp, changedPort: $changedPort}';
  }
}

String generateTransactionId() {
  return List.generate(32, (index) => Random.secure().nextInt(16).toRadixString(16).toUpperCase()).join('');
}

Future<NATTestResult> performNATTest(
  RawDatagramSocket socket,
  String stunHost,
  int stunPort,
  String sourceIp,
  int sourcePort, {
  String extraData = "",
  int count = 3,
}) async {
  try {
    String strLen = (extraData.length ~/ 2).toRadixString(16).padLeft(4, '0');
    String transactionId = generateTransactionId();
    String strData = BIND_REQUEST_MSG + strLen + transactionId + extraData;
    List<int> hexData = HEX.decode(strData);
    InternetAddress address = (await InternetAddress.lookup(stunHost)).first;
    print("sendto: ${stunHost}(${address.address}):${stunPort}");
    socket.send(hexData, address, stunPort);
    Completer<NATTestResult> completer = Completer();
    completers[transactionId] = completer;
    return await completer.future.timeout(const Duration(seconds: 3));
  } catch (e) {
    if (count > 0) {
      return performNATTest(socket, stunHost, stunPort, sourceIp, sourcePort, extraData: extraData, count: count - 1);
    }
    return NATTestResult.UNKNOWN;
  }
}

Future<NATTestResult> determineNatType({
  required RawDatagramSocket socket,
  required String stunHost,
  required int stunPort,
  required String sourceIp,
  required int sourcePort,
}) async {
  //1.首先客户端要发送一个ECHO请求给服务端（提供STUN服务），服务端收到请求之后，通过同样的IP地址和端口，给我们返回一个信息回来。
  print("Do Test1");
  NATTestResult result = await performNATTest(socket, stunHost, stunPort, sourceIp, sourcePort);
  print("Result: ${result}");
  //2.那在客户端就要等这个消息回复，那么设置一个超时器，看每个消息是否可以按时回来，那如果我们发送的数据没有回来，则说明这个UDP是不通的，我们就不要再进行判断了（网络不通，不需要判断）。
  if (!result.resp) {
    result.type = NATType.blocked;
    return result;
  }

  print("Do Test2");
  String extraData = "$CHANGE_REQUEST$SOURCE_ADDRESS$IP_ADDRESS_AND_PORT_LENGTH_6_BYTES";
  NATTestResult result2 = await performNATTest(socket, stunHost, stunPort, sourceIp, sourcePort, extraData: extraData);
  print("Result: ${result2}");
  //3.如果我们收到了服务端的响应，那么就能拿到我们这个客户端出口的公网的IP地址和端口，这个时候要判断一下公网的IP地址和本机的IP地址（NAT内部址！！！）是否是一致的，如果是一致的，说明本机没有在NAT之后而是一个公网地址；地

  //4.接下来要做进一步判断，就是判断我们的公网地址是不是一个完全的公网地址，这时我们再发送一个信息到第一个IP地址和端口，那服务端收到这个请求之后呢，
  // 它使用第二个IP地址和端口给我们回消息，如果我们真是一个完全的公网IP地址和端口提供一个服务的话，那其他任何公网上的主机都可以向我发送请求和回数据，
  // 这时候我都是能收到的，那如果我能收到，那就说明就是一个公网的地址，所以我们就没有在NAT之后就完全可以接收数据了。
  if (result.externalIp == sourceIp && result2.resp) {
    result.type = NATType.openInternet;
    return result;
  }

  //5.那如果我们收不到，那说明我是在一个防火墙之后，而且一个对称的防火墙。（可以认为与对称NAT一样）
  if (result.externalIp == sourceIp && !result2.resp) {
    result.type = NATType.symmetricUDPFirewall;
    return result;
  }

  //6.如果我收到的公网的IP与我本地的IP不一致，那就说明我们确实是在NAT之后，那既然是在NAT之后我们就要对各种类型作判断了。
  //7.这时我们再发送一个请求到服务端的第一个IP地址和端口，而服务端通过第二个IP地址和端口给我们回消息，那这时候我们要判断NAT的类型是不是完全锥型，
  // 如果我们出去一个请求，在我们的NAT服务和网关上建立了一个内网地址和外网地址的映射表之后，
  // 那其他公网上的主机都可以向我这个公网IP地址（含端口）发送消息，并且我可以接收到，那么这个时候可以收到的话，我们就是一个完全锥型NAT。
  if (result.externalIp != sourceIp && result2.resp) {
    result.type = NATType.fullCone;
    return result;
  }
  print("Do Test3");
  NATTestResult result3 = await performNATTest(socket, result.changedIp, result.changedPort, sourceIp, sourcePort);
  print("Result: ${result3}");
  //8.那么如果收不到的话，需要做进一步的判断，这时候需要（客户端主动发送数据，用来探测对称型）向服务端的第二个IP地址和端口发送数据，
  // 那么此时服务端会用同样的IP地址和端口给我们回数据，那么这时候它也会带回一个公网的IP地址来，
  // 但是如果我们的出口，就是向第二个IP地址发送了请求带回的外网IP与端口与我们第一发送的请求带回的IP地址和端口（主要是端口）如果是不一样的，
  // 那就说明是对称型NAT；---对称型NAT每次出去都会在映射表上形成不同的外网IP地址和端口！！！！
  if (!result3.resp) {
    result.type = NATType.changedAddressError;
    return result;
  }

  if (result.externalIp == result3.externalIp && result.externalPort == result3.externalPort) {
    print("Do Test4");
    String changePortRequest = "$CHANGE_REQUEST$SOURCE_ADDRESS$PORT_LENGTH_2_BYTES";
    NATTestResult result4 = await performNATTest(socket, result.changedIp, result.changedPort, sourceIp, sourcePort, extraData: changePortRequest);
    print("Result: ${result4}");
    //9.如果一样（没有修改映射表，没有新建一个映射关系，即是说明客户端的外网IP和端口不变）就说明是限制型的，限制型分为两种一种是IP限制型，一种是端口限制型，所以还需要做进一步的检测。
    // 这个时候客户端主动再向服务端第一个IP地址和端口发送一个请求，如果服务端回信息时使用的是之前回复消息所使用的同一个IP地址，但是不是同一个的端口号，那么这时候我们就可以判断是否可以接收到，如果不能接收到，说明是对端口做了限制，
    // 所以是端口限制型的NAT，如果可以收到就说明是一个IP地址限制型的NAT。
    if (result4.resp) {
      result.type = NATType.restrictNAT;
    } else {
      result.type = NATType.restrictPortNAT;
    }
  } else {
    //8.那么如果收不到的话，需要做进一步的判断，这时候需要（客户端主动发送数据，用来探测对称型）向服务端的第二个IP地址和端口发送数据，
    // 那么此时服务端会用同样的IP地址和端口给我们回数据，那么这时候它也会带回一个公网的IP地址来，
    // 但是如果我们的出口，就是向第二个IP地址发送了请求带回的外网IP与端口与我们第一发送的请求带回的IP地址和端口（主要是端口）如果是不一样的，
    // 那就说明是对称型NAT；---对称型NAT每次出去都会在映射表上形成不同的外网IP地址和端口！！！！
    result.type = NATType.symmetricNAT;
  }

  return result;
}

void handleData(RawSocketEvent event, RawDatagramSocket socket) {
  try {
    if (event == RawSocketEvent.read) {
      Datagram? datagram = socket.receive();
      if (datagram == null) {
        return;
      }
      print("recvfrom: ${datagram.address}:${datagram.port}");
      NATTestResult result = NATTestResult.UNKNOWN;

      String msgType = HEX.encode(datagram.data.sublist(0, 2));
      bool bindRespMsg = msgType == BIND_RESPONSE_MSG;
      String transactionId = HEX.encode(datagram.data.sublist(4, 20)).toUpperCase();
      if (bindRespMsg) {
        int lenMessage = int.parse(HEX.encode(datagram.data.sublist(2, 4)), radix: 16);
        int lenRemain = lenMessage;
        int base = 20;
        result.resp = true;

        while (lenRemain > 0) {
          String attrType = HEX.encode(datagram.data.sublist(base, base + 2));
          int attrLen = int.parse(HEX.encode(datagram.data.sublist(base + 2, base + 4)), radix: 16);

          if (attrType == MAPPED_ADDRESS) {
            int port = int.parse(HEX.encode(datagram.data.sublist(base + 6, base + 8)), radix: 16);
            String ip = datagram.data.sublist(base + 8, base + 12).map((byte) => byte.toString()).join('.');
            result.externalIp = ip;
            result.externalPort = port;
          }

          if (attrType == SOURCE_ADDRESS) {
            int port = int.parse(HEX.encode(datagram.data.sublist(base + 6, base + 8)), radix: 16);
            String ip = datagram.data.sublist(base + 8, base + 12).map((byte) => byte.toString()).join('.');
            result.sourceIp = ip;
            result.sourcePort = port;
          }

          if (attrType == CHANGED_ADDRESS) {
            int port = int.parse(HEX.encode(datagram.data.sublist(base + 6, base + 8)), radix: 16);
            String ip = datagram.data.sublist(base + 8, base + 12).map((byte) => byte.toString()).join('.');
            result.changedIp = ip;
            result.changedPort = port;
          }

          base += 4 + attrLen;
          lenRemain -= (4 + attrLen);
        }
        completers[transactionId]?.complete(result);
      }
    }
  } catch (e) {
    print(e);
  }
}

Future<NATTestResult> getNatType({
  String stunHost = "stun.syncthing.net",
  int stunPort = 3478,
  String sourceIp = "0.0.0.0",
  int sourcePort = 54320,
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress(sourceIp), sourcePort);
  socket.timeout(const Duration(seconds: 2));
  socket.listen((event) => handleData(event, socket));
  final nat = await determineNatType(
    socket: socket,
    stunHost: stunHost,
    stunPort: stunPort,
    sourceIp: sourceIp,
    sourcePort: sourcePort,
  );
  socket.close();
  return nat;
}

main() async {
  print(await getNatType());
}
