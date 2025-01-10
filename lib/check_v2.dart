import 'dart:async';
import 'dart:io';

import 'package:stun/stun.dart';

main() async {
  await testMappingPhase();
}

List<String> _localAddresses = [];

StunClient _stunClient = StunClient.create(
  transport: Transport.udp,
  serverHost: "stun.hot-chilli.net",
  serverPort: 3478,
  localIp: "0.0.0.0",
  localPort: 54322,
  stunProtocol: StunProtocol.RFC5780,
);

enum NatMappingBehavior {
  Block,
  EndpointIndependent,
  AddressDependent,
  AddressAndPortDependent,
}

enum NatFilteringBehavior {
  Block,
  EndpointIndependent,
  AddressDependent,
  AddressAndPortDependent,
}

Future<void> testMappingPhase() async {
  await _initializeLocalAddresses();
  var mb = await _testMappingPhase1();
  print(mb);
  var fb = await _testFilteringPhase1();
  print(fb);
}

_initializeLocalAddresses() async {
  for (NetworkInterface networkInterface in await NetworkInterface.list()) {
    for (InternetAddress internetAddress in networkInterface.addresses) {
      _localAddresses.add(internetAddress.address);
    }
  }
}

Future<NatMappingBehavior> _testMappingPhase1() async {
  try {
    //1）客户端A以IP_CA: PORT_CA给STUN Server的IP_SA: PORT_SA发送一个bind请求，STUN server以IP_SA: PORT_SA给客户端A的IP_CA: PORT_CA回复响应，
    // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA1: PORT_MCA1，STUN Server的另外一个IP地址和端口为：IP_SB: PORT_SB）。
    // 这个时候客户端判断，如果IP_CA: PORT_CA == IP_MCA1: PORT_MCA1，那么该客户端是拥有公网IP的，NAT类型侦测结束。
    StunMessageRfc5780 message = await _stunClient.sendAndAwait(_stunClient.createBindingStunMessage(), isAutoClose: true) as StunMessageRfc5780;
    if (_localAddresses.contains(message.xorMappedAddressAttribute.addressDisplayName) && message.xorMappedAddressAttribute.port == 3478) {
      return NatMappingBehavior.EndpointIndependent;
    }
    return _testMappingPhase2(message);
  } on TimeoutException catch (e) {
    return NatMappingBehavior.Block;
  } catch (e) {
    print(e);
    rethrow;
  }
}

Future<NatMappingBehavior> _testMappingPhase2(StunMessageRfc5780 message1) async {
  try {
    // 2）客户端A以IP_CA: PORT_CA给STUN server的IP_SB: PORT_SA(相对步骤1 ip改变了)发送一个bind请求，STUN server以IP_SB: PORT_SA给客户端A的IP_CA: PORT_CA回复响应，
    // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA2: PORT_MCA2）。
    // 这个时候客户端判断，
    // 如果IP_MCA1: PORT_MCA1 == IP_MCA2: PORT_MCA2，那么NAT是Endpoint Independent Mapping的映射规则，也就是同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是固定不变的；
    // 如果IP_MCA1: PORT_MCA1 != IP_MCA2: PORT_MCA2,那么就要进行下面的第3步测试。
    _stunClient.serverHost = message1.otherAddress.addressDisplayName!;
    StunMessageRfc5780 message = await _stunClient.sendAndAwait(_stunClient.createBindingStunMessage(), isAutoClose: true) as StunMessageRfc5780;
    if (message.xorMappedAddressAttribute == message1.xorMappedAddressAttribute) {
      return NatMappingBehavior.EndpointIndependent;
    }
    return _testMappingPhase3(message1, message);
  } on TimeoutException catch (e) {
    return NatMappingBehavior.Block;
  } catch (e) {
    print(e);
    rethrow;
  }
}

Future<NatMappingBehavior> _testMappingPhase3(StunMessageRfc5780 message1, StunMessageRfc5780 message2) async {
  try {
    // 3）客户端A以IP_CA: PORT_CA给STUN server的IP_SB: PORT_SB(相对步骤1 ip和port改变了)发送一个bind请求，STUN server以IP_SB: PORT_SB给客户端A的IP_CA: PORT_CA回复响应，
    // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA3: PORT_MCA3）。
    // 这个时候客户端判断，
    // 如果IP_MCA2: PORT_MCA2== IP_MCA3: PORT_MCA3，那么NAT是Address Dependent Mapping的映射规则，也就是只要是目的IP是相同的，那么同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是固定不变的；
    // 如果IP_MCA2: PORT_MCA2!= IP_MCA3: PORT_MCA3，那么NAT是Address and Port Dependent Mapping，只要目的IP和PORT中有一个不一样，那么同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是不一样的。
    _stunClient.serverHost = message1.otherAddress.addressDisplayName!;
    _stunClient.serverPort = message1.otherAddress.port;
    StunMessageRfc5780 message = await _stunClient.sendAndAwait(_stunClient.createBindingStunMessage(), isAutoClose: true) as StunMessageRfc5780;
    if (message.xorMappedAddressAttribute == message2.xorMappedAddressAttribute) {
      return NatMappingBehavior.AddressDependent;
    } else {
      return NatMappingBehavior.AddressAndPortDependent;
    }
  } on TimeoutException catch (e) {
    return NatMappingBehavior.Block;
  } catch (e) {
    print(e);
    rethrow;
  }
}

Future<NatFilteringBehavior> _testFilteringPhase1() async {
  try {
    // 4）客户端A以IP_CA: PORT_CA给STUN server的IP_SA: PORT_SA发送一个bind请求（请求中带CHANGE-REQUEST attribute来要求stun server改变IP和PORT来响应），STUN server以IP_SB: PORT_SB给客户端A的IP_CA: PORT_CA回复响应。
    // 如果客户端A能收到STUN server的响应，那么NAT是Endpoint-Independent Filtering的过滤规则，也就是只要给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据都能通过NAT到达客户端A的IP_CA: PORT_CA（这种过滤规则的NAT估计很少）。
    // 如果不能收到STUN server的响应，那么需要进行下面的第五步测试。
    StunMessage message = await _stunClient.sendAndAwait(_stunClient.createChangeStunMessage(flagChangeIp: true, flagChangePort: true), isAutoClose: true);
    return NatFilteringBehavior.EndpointIndependent;
  } on TimeoutException catch (e) {
    return _testFilteringPhase2();
  } catch (e) {
    print(e);
    rethrow;
  }
}

Future<NatFilteringBehavior> _testFilteringPhase2() async {
  try {
    // 5）客户端A以IP_CA: PORT_CA给STUN server的IP_SA: PORT_SA发送一个bind请求（请求中带CHANGE-REQUEST attribute来要求stun server改变PORT来响应），STUN server以IP_SA: PORT_SB给客户端A的IP_CA: PORT_CA回复响应。
    // 如果客户端A能收到STUN server的响应，NAT是Address-Dependent Filtering的过滤规则，也就是只要之前客户端A以IP_CA: PORT_CA给IP为IP_D的主机发送过数据，
    // 那么在NAT映射的有效期内，IP为IP_D的主机以任何端口给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据都能通过NAT到达客户端A的IP_CA: PORT_CA；
    // 如果不能收到响应，NAT是Address and Port-Dependent Filtering的过滤规则，也即是只有之前客户端A以IP_CA: PORT_CA给目的主机的IP_D: PORT_D发送过数据，
    // 那么在NAT映射的有效期内，只有以IP_D: PORT_D给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据才能通过NAT到达客户端A的IP_CA: PORT_CA。
    StunMessage message = await _stunClient.sendAndAwait(_stunClient.createChangeStunMessage(flagChangeIp: false, flagChangePort: true), isAutoClose: true);
    return NatFilteringBehavior.AddressDependent;
  } on TimeoutException catch (e) {
    return NatFilteringBehavior.AddressAndPortDependent;
  } catch (e) {
    print(e);
    rethrow;
  }
}
