import 'dart:async';
import 'dart:io';

import 'package:stun/src/stun_message_rfc5389.dart' as rfc5389;
import 'package:stun/src/stun_message_rfc5780.dart' as rfc5780;
import 'package:stun/stun.dart';

main() async {
  await a();
  var b = await m1();
  print(b);
}

List<String> localAddresses = [];

enum Mapping {
  Block,
  EndpointIndependent,
  AddressDependent,
  AddressAndPortDependent,
}

a() async {
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      String address = addr.address;
      localAddresses.add(address);
    }
  }
  print(localAddresses);
}

StunClient stunClient = StunClient.create(
  transport: Transport.udp,
  serverHost: "stun.hot-chilli.net",
  serverPort: 3478,
  localIp: "0.0.0.0",
  localPort: 54320,
  stunProtocol: StunProtocol.RFC5780,
);

Future<Mapping> m1() async {
  try {
    //1）客户端A以IP_CA: PORT_CA给STUN Server的IP_SA: PORT_SA发送一个bind请求，STUN server以IP_SA: PORT_SA给客户端A的IP_CA: PORT_CA回复响应，
    // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA1: PORT_MCA1，STUN Server的另外一个IP地址和端口为：IP_SB: PORT_SB）。
    // 这个时候客户端判断，如果IP_CA: PORT_CA == IP_MCA1: PORT_MCA1，那么该客户端是拥有公网IP的，NAT类型侦测结束。
    StunMessage message = await stunClient.sendAndAwait(stunClient.createBindingStunMessage());
    stunClient.disconnect();
    if (localAddresses.contains(message.xorMappedAddressAttribute.addressDisplayName) && message.xorMappedAddressAttribute.port == 3478) {
      return Mapping.EndpointIndependent;
    }
    return m2(message);
  } on TimeoutException catch (e) {
    return Mapping.Block;
  } catch (e) {
    print(e);
    rethrow;
  }
}

Future<Mapping> m2(StunMessage message1) async {
  try {
    // 2）客户端A以IP_CA: PORT_CA给STUN server的IP_SB: PORT_SA(相对步骤1 ip改变了)发送一个bind请求，STUN server以IP_SB: PORT_SA给客户端A的IP_CA: PORT_CA回复响应，
    // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA2: PORT_MCA2）。
    // 这个时候客户端判断，
    // 如果IP_MCA1: PORT_MCA1 == IP_MCA2: PORT_MCA2，那么NAT是Endpoint Independent Mapping的映射规则，也就是同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是固定不变的；
    // 如果IP_MCA1: PORT_MCA1 != IP_MCA2: PORT_MCA2,那么就要进行下面的第3步测试。
    stunClient.serverHost = message1.otherAddress.addressDisplayName!;
    StunMessage message = await stunClient.sendAndAwait(stunClient.createBindingStunMessage());
    stunClient.disconnect();
    if (message1.xorMappedAddressAttribute == message.xorMappedAddressAttribute) {
      return Mapping.EndpointIndependent;
    }
    return m3(message1, message);
  } on TimeoutException catch (e) {
    return Mapping.Block;
  } catch (e) {
    print(e);
    rethrow;
  }
}

Future<Mapping> m3(StunMessage message1, StunMessage message2) async {
  try {
    // 3）客户端A以IP_CA: PORT_CA给STUN server的IP_SB: PORT_SB(相对步骤1 ip和port改变了)发送一个bind请求，STUN server以IP_SB: PORT_SB给客户端A的IP_CA: PORT_CA回复响应，
    // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA3: PORT_MCA3）。
    // 这个时候客户端判断，
    // 如果IP_MCA2: PORT_MCA2== IP_MCA3: PORT_MCA3，那么NAT是Address Dependent Mapping的映射规则，也就是只要是目的IP是相同的，那么同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是固定不变的；
    // 如果IP_MCA2: PORT_MCA2!= IP_MCA3: PORT_MCA3，那么NAT是Address and Port Dependent Mapping，只要目的IP和PORT中有一个不一样，那么同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是不一样的。
    stunClient.serverHost = message1.otherAddress.addressDisplayName!;
    stunClient.serverPort = message1.otherAddress.port;
    StunMessage message = await stunClient.sendAndAwait(stunClient.createBindingStunMessage());
    stunClient.disconnect();
    if (message2.xorMappedAddressAttribute == message.xorMappedAddressAttribute) {
      return Mapping.AddressDependent;
    } else {
      return Mapping.AddressAndPortDependent;
    }
  } on TimeoutException catch (e) {
    return Mapping.Block;
  } catch (e) {
    print(e);
    rethrow;
  }
}

b() async {
  StunClient stunClient = await StunClient.create(
    transport: Transport.udp,
    serverHost: "stun.hot-chilli.net",
    serverPort: 3478,
    localIp: "0.0.0.0",
    localPort: 54320,
    stunProtocol: StunProtocol.RFC5780,
  );
  StunMessage message1 = await stunClient.sendAndAwait(stunClient.createBindingStunMessage());
  message1.attributes.firstWhere((e) => e.type == StunAttributes.TYPE_MAPPED_ADDRESS) as rfc5389.MappedAddressAttribute;
  var otherAddress1 = message1.attributes.firstWhere((e) => e.type == StunAttributes.TYPE_OTHER_ADDRESS) as rfc5780.OtherAddress;
  var xorMappedAddressAttribute1 = message1.attributes.firstWhere((e) => e.type == StunAttributes.TYPE_XOR_MAPPED_ADDRESS) as rfc5389.XorMappedAddressAttribute;

  StunClient stunClient2 = await StunClient.create(
    transport: Transport.udp,
    serverHost: otherAddress1.addressDisplayName!,
    serverPort: 3478,
    localIp: "0.0.0.0",
    localPort: 54320,
    stunProtocol: StunProtocol.RFC5780,
  );

  var createBindingStunMessage2 = stunClient.createBindingStunMessage();
  createBindingStunMessage2.attributes.add(rfc5780.ChangeRequest(StunAttributes.TYPE_CHANGE_REQUEST, 8, true, true));
  StunMessage message2 = await stunClient2.sendAndAwait(createBindingStunMessage2);

  //Endpoint-Independent Filtering

  //:::::: timeout
  var createBindingStunMessage3 = stunClient.createBindingStunMessage();
  createBindingStunMessage3.attributes.add(rfc5780.ChangeRequest(StunAttributes.TYPE_CHANGE_REQUEST, 8, true, true));
  StunMessage message3 = await stunClient2.sendAndAwait(createBindingStunMessage3);
  //Address-Dependent

  //::::::: timeout
  //Address and Port-Dependent Filtering.
}
