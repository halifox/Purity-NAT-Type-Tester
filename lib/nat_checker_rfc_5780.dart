import 'dart:async';
import 'dart:io';

import 'package:purity_nat_type_tester/checker_event.dart';
import 'package:stun/stun.dart';

/// Mapping Behavior：
///
/// 1）Endpoint-Independent Mapping：
/// 对于一个内网的EndpointP，其映射的外网EndpointG是基本固定的，不会随着通信外部主机的不同而变化。
///
/// 2）Address and Port-Dependent Mapping：
/// 对于一个内网的EndpointP，如果与之通信的外部为EndpointGB1，那么EndpointP就会被NAT映射成EndpointG1；
/// 如果与之通信的外部为EndpointGB2，那么EndpointP就会被NAT映射成EndpointG2。
/// 也就是只要之通信的外部为EndpointGB发生变化，那么映射的外网EndpointG就会变化。
///
/// 3）Address-Dependent Mapping：
/// 对于一个内网的EndpointP，如果与之通信的外部为EndpointGB1，那么EndpointP就会被NAT映射成EndpointG1；
/// 如果与之通信的外部为EndpointGB2(如果EndpointGB2的IP和EndpointGB1的相同)，
/// 那么EndpointP同样会被NAT映射成EndpointG1，否则就会被NAT映射成EndpointG2。
/// 也就是只要之通信的外部为EndpointGB的IP发生变化，那么映射的外网EndpointG就会变化。
enum NatMappingBehavior {
  Block,
  EndpointIndependent,
  AddressDependent,
  AddressAndPortDependent,
}

/// Filtering Behavior：
///
/// 1）Endpoint-Independent Filtering：
/// 对于这种过滤类型，NAT在在自己的一个外网EndpointG1收到数据包，只要找到与之对应的内网EndpointP1，
/// NAT就会转发这个数据包给相应的内网EndpointP1，不管这个数据包的来源是那里。(一般来说，这样过滤规则的NAT是比较少的，因为这样的安全系数比较低)
///
/// 2）Address and Port-Dependent Filtering：
/// 对于这种过滤类型，NAT在自己的一个外网EndpointG1收到来源是EndpointGA1数据包，
/// 这个时候NAT要判断自己是否曾经通过自己的EndpointG1给EndpointGA1发送过数据包，
/// 如果曾经发过，那么NAT就允许该数据包通过NAT并路由给内网与之对于的内网EndpointP1；
/// 如果没发过，那么NAT会不允许该数据包通过NAT。
///
/// 3）Address-Dependent Filtering：
/// 对于这种过滤类型，NAT在自己的一个外网EndpointG1收到来源是EndpointGA1数据包，
/// 这个时候NAT要判断自己是否曾经通过自己的EndpointG1给和EndpointGA1的IP相同的机器发送过数据包(这里会忽略端口)，
/// 如果曾经发过，那么NAT就允许该数据包通过NAT并路由给内网与之对于的内网EndpointP1；
/// 如果没发过，那么NAT会不允许该数据包通过NAT。
enum NatFilteringBehavior {
  Block,
  EndpointIndependent,
  AddressDependent,
  AddressAndPortDependent,
}

/// 要进行NAT类型的侦测，需要一个具有双公网IP的服务器来协助侦测，我们称该服务器为STUN Server。假设STUN Server的双IP分别为IP_SA(125.227.152.3)和IP_SB(125.227.152.4) 监听的两个端口分别为PORT_SA(4777)和PORT_SB(4888)，客户端A的内网和端口分别为IP_CA(10.70.142.12)和PORT_CA(1234)。
///
/// 1）客户端A以IP_CA: PORT_CA给STUN Server的IP_SA: PORT_SA发送一个bind请求，STUN server以IP_SA: PORT_SA给客户端A的IP_CA: PORT_CA回复响应，响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA1: PORT_MCA1，STUN Server的另外一个IP地址和端口为：IP_SB: PORT_SB）。这个时候客户端判断，如果IP_CA: PORT_CA == IP_MCA1: PORT_MCA1，那么该客户端是拥有公网IP的，NAT类型侦测结束。
///
/// 2）客户端A以IP_CA: PORT_CA给STUN server的IP_SB: PORT_SA(相对步骤1 ip改变了)发送一个bind请求，STUN server以IP_SB: PORT_SA给客户端A的IP_CA: PORT_CA回复响应，响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA2: PORT_MCA2）。这个时候客户端判断，如果IP_MCA1: PORT_MCA1 == IP_MCA2: PORT_MCA2，那么NAT是Endpoint Independent Mapping的映射规则，也就是同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是固定不变的；如果IP_MCA1: PORT_MCA1 != IP_MCA2: PORT_MCA2,那么就要进行下面的第3步测试。
///
/// 3）客户端A以IP_CA: PORT_CA给STUN server的IP_SB: PORT_SB(相对步骤1 ip和port改变了)发送一个bind请求，STUN server以IP_SB: PORT_SB给客户端A的IP_CA: PORT_CA回复响应，响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA3: PORT_MCA3）。这个时候客户端判断，如果IP_MCA2: PORT_MCA2== IP_MCA3: PORT_MCA3，那么NAT是Address Dependent Mapping的映射规则，也就是只要是目的IP是相同的，那么同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是固定不变的；如果IP_MCA2: PORT_MCA2!= IP_MCA3: PORT_MCA3，那么NAT是Address and Port Dependent Mapping，只要目的IP和PORT中有一个不一样，那么同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是不一样的。
///
/// 以上三个步骤是进行Mapping Behavior的侦测，下面两个步骤是进行Filtering Behavior侦测：
///
/// 4）客户端A以IP_CA: PORT_CA给STUN server的IP_SA: PORT_SA发送一个bind请求（请求中带CHANGE-REQUEST attribute来要求stun server改变IP和PORT来响应），STUN server以IP_SB: PORT_SB给客户端A的IP_CA: PORT_CA回复响应。如果客户端A能收到STUN server的响应，那么NAT是Endpoint-Independent Filtering的过滤规则，也就是只要给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据都能通过NAT到达客户端A的IP_CA: PORT_CA（这种过滤规则的NAT估计很少）。如果不能收到STUN server的响应，那么需要进行下面的第五步测试。
///
/// 5）客户端A以IP_CA: PORT_CA给STUN server的IP_SA: PORT_SA发送一个bind请求（请求中带CHANGE-REQUEST attribute来要求stun server改变PORT来响应），STUN server以IP_SA: PORT_SB给客户端A的IP_CA: PORT_CA回复响应。如果客户端A能收到STUN server的响应，NAT是Address-Dependent Filtering的过滤规则，也就是只要之前客户端A以IP_CA: PORT_CA给IP为IP_D的主机发送过数据，那么在NAT映射的有效期内，IP为IP_D的主机以任何端口给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据都能通过NAT到达客户端A的IP_CA: PORT_CA；如果不能收到响应，NAT是Address and Port-Dependent Filtering的过滤规则，也即是只有之前客户端A以IP_CA: PORT_CA给目的主机的IP_D: PORT_D发送过数据，那么在NAT映射的有效期内，只有以IP_D: PORT_D给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据才能通过NAT到达客户端A的IP_CA: PORT_CA。
///
/// 通过以上5个步骤就能完成完整的NAT类型侦测。
///
/// 将NAT映射规则和过滤规则组合起来就形成9中不同的NAT行为类型：
///
///     1）Endpoint Independent Mapping和Endpoint-Independent Filtering组合对应于RFC3489中的Full Cone NAT；
///     2）Endpoint Independent Mapping和Address-Dependent Filtering组合对应于RFC3489中的Restricted Cone NAT；
///     3）Endpoint Independent Mapping和Address and Port-Dependent Filtering组合对应于RFC3489中的Port Restricted Cone NAT；
///     4）Address and Port-Dependent Mapping和Address and Port-Dependent Filtering组合是RFC3489中所说的Symmetric NAT。
///
///
/// 可见RFC3489只描述了9种NAT组合行为类型中的4种。最后一个文档rfc5769，定义了一些STUN协议的测试数据用于测试STUN server的正确性。
class NatChecker {
  String serverHost;
  int serverPort;
  String localIp;
  int localPort;

  NatChecker({
    this.serverHost = "stun.hot-chilli.net",
    this.serverPort = 3478,
    this.localIp = "0.0.0.0",
    this.localPort = 54320,
  });

  List<String> _localAddresses = [];

  late StunClient _stunClient = StunClient.create(
    transport: Transport.udp,
    serverHost: serverHost,
    serverPort: serverPort,
    localIp: localIp,
    localPort: localPort,
    stunProtocol: StunProtocol.RFC5780,
  );

  Future<(NatMappingBehavior, NatFilteringBehavior)> check() async {
    checkerEvent.result = EventState.running;
    _localAddresses = await _initializeLocalAddresses();
    NatMappingBehavior natMappingBehavior = await _performPhase1MappingTest();
    NatFilteringBehavior natFilteringBehavior = await _performPhase1FilteringTest();
    checkerEvent.result = EventState.success;
    return (natMappingBehavior, natFilteringBehavior);
  }

  Future<List<String>> _initializeLocalAddresses() async {
    try {
      checkerEvent.initializeLocalAddresses = EventState.running;
      updateCheckerEvent();
      List<String> addresses = [];
      for (NetworkInterface networkInterface in await NetworkInterface.list()) {
        for (InternetAddress internetAddress in networkInterface.addresses) {
          addresses.add(internetAddress.address);
        }
      }
      checkerEvent.initializeLocalAddresses = EventState.success;
      updateCheckerEvent();
      return addresses;
    } catch (e) {
      checkerEvent.initializeLocalAddresses = EventState.error;
      updateCheckerEvent();
      rethrow;
    }
  }

  Future<NatMappingBehavior> _performPhase1MappingTest() async {
    try {
      checkerEvent.performPhase1MappingTest = EventState.running;
      updateCheckerEvent();
      //1）客户端A以IP_CA: PORT_CA给STUN Server的IP_SA: PORT_SA发送一个bind请求，STUN server以IP_SA: PORT_SA给客户端A的IP_CA: PORT_CA回复响应，
      // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA1: PORT_MCA1，STUN Server的另外一个IP地址和端口为：IP_SB: PORT_SB）。
      // 这个时候客户端判断，如果IP_CA: PORT_CA == IP_MCA1: PORT_MCA1，那么该客户端是拥有公网IP的，NAT类型侦测结束。
      StunMessageRfc5780 message = await _stunClient.sendAndAwait(_stunClient.createBindingStunMessage(), isAutoClose: true) as StunMessageRfc5780;

      if (!message.attributes.any((e) => e.type == StunAttributes.TYPE_XOR_MAPPED_ADDRESS)) {
        //服务器不支持rfc5780
        throw Exception('服务器不支持 RFC5780 协议');
      }
      if (_localAddresses.contains(message.xorMappedAddressAttribute.addressDisplayName) && message.xorMappedAddressAttribute.port == serverPort) {
        checkerEvent.performPhase1MappingTest = EventState.success;
        checkerEvent.performPhase2MappingTest = EventState.never;
        checkerEvent.performPhase3MappingTest = EventState.never;
        updateCheckerEvent();
        return NatMappingBehavior.EndpointIndependent;
      }
      checkerEvent.performPhase1MappingTest = EventState.success;
      updateCheckerEvent();
      return _performPhase2MappingTest(message);
    } on TimeoutException catch (e) {
      checkerEvent.performPhase1MappingTest = EventState.timeout;
      updateCheckerEvent();
      return NatMappingBehavior.Block;
    } catch (e, stackTrace) {
      checkerEvent.performPhase1MappingTest = EventState.error;
      updateCheckerEvent();
      rethrow;
    }
  }

  Future<NatMappingBehavior> _performPhase2MappingTest(StunMessageRfc5780 message1) async {
    try {
      checkerEvent.performPhase2MappingTest = EventState.running;
      updateCheckerEvent();
      // 2）客户端A以IP_CA: PORT_CA给STUN server的IP_SB: PORT_SA(相对步骤1 ip改变了)发送一个bind请求，STUN server以IP_SB: PORT_SA给客户端A的IP_CA: PORT_CA回复响应，
      // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA2: PORT_MCA2）。
      // 这个时候客户端判断，
      // 如果IP_MCA1: PORT_MCA1 == IP_MCA2: PORT_MCA2，那么NAT是Endpoint Independent Mapping的映射规则，也就是同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是固定不变的；
      // 如果IP_MCA1: PORT_MCA1 != IP_MCA2: PORT_MCA2,那么就要进行下面的第3步测试。
      _stunClient.serverHost = message1.otherAddress.addressDisplayName!;
      StunMessageRfc5780 message = await _stunClient.sendAndAwait(_stunClient.createBindingStunMessage(), isAutoClose: true) as StunMessageRfc5780;
      if (!message.attributes.any((e) => e.type == StunAttributes.TYPE_XOR_MAPPED_ADDRESS)) {
        //服务器不支持rfc5780
        throw Exception('服务器不支持 RFC5780 协议');
      }
      if (message.xorMappedAddressAttribute == message1.xorMappedAddressAttribute) {
        checkerEvent.performPhase2MappingTest = EventState.success;
        checkerEvent.performPhase3MappingTest = EventState.never;
        updateCheckerEvent();
        return NatMappingBehavior.EndpointIndependent;
      }
      checkerEvent.performPhase2MappingTest = EventState.success;
      updateCheckerEvent();
      return _performPhase3MappingTest(message1, message);
    } on TimeoutException catch (e) {
      checkerEvent.performPhase2MappingTest = EventState.timeout;
      updateCheckerEvent();
      return NatMappingBehavior.Block;
    } catch (e, stackTrace) {
      checkerEvent.performPhase2MappingTest = EventState.error;
      updateCheckerEvent();
      rethrow;
    }
  }

  Future<NatMappingBehavior> _performPhase3MappingTest(StunMessageRfc5780 message1, StunMessageRfc5780 message2) async {
    try {
      checkerEvent.performPhase3MappingTest = EventState.running;
      updateCheckerEvent();
      // 3）客户端A以IP_CA: PORT_CA给STUN server的IP_SB: PORT_SB(相对步骤1 ip和port改变了)发送一个bind请求，STUN server以IP_SB: PORT_SB给客户端A的IP_CA: PORT_CA回复响应，
      // 响应内容大体为：（NAT映射后的IP地址和端口为：IP_MCA3: PORT_MCA3）。
      // 这个时候客户端判断，
      // 如果IP_MCA2: PORT_MCA2== IP_MCA3: PORT_MCA3，那么NAT是Address Dependent Mapping的映射规则，也就是只要是目的IP是相同的，那么同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是固定不变的；
      // 如果IP_MCA2: PORT_MCA2!= IP_MCA3: PORT_MCA3，那么NAT是Address and Port Dependent Mapping，只要目的IP和PORT中有一个不一样，那么同样的内网地址IP_CA: PORT_CA经过这种NAT映射后的IP_M: PORT_M是不一样的。
      _stunClient.serverHost = message1.otherAddress.addressDisplayName!;
      _stunClient.serverPort = message1.otherAddress.port;
      StunMessageRfc5780 message = await _stunClient.sendAndAwait(_stunClient.createBindingStunMessage(), isAutoClose: true) as StunMessageRfc5780;
      if (!message.attributes.any((e) => e.type == StunAttributes.TYPE_XOR_MAPPED_ADDRESS)) {
        //服务器不支持rfc5780
        throw Exception('服务器不支持 RFC5780 协议');
      }
      if (message.xorMappedAddressAttribute == message2.xorMappedAddressAttribute) {
        checkerEvent.performPhase3MappingTest = EventState.success;
        updateCheckerEvent();
        return NatMappingBehavior.AddressDependent;
      } else {
        checkerEvent.performPhase3MappingTest = EventState.success;
        updateCheckerEvent();
        return NatMappingBehavior.AddressAndPortDependent;
      }
    } on TimeoutException catch (e) {
      checkerEvent.performPhase3MappingTest = EventState.timeout;
      updateCheckerEvent();
      return NatMappingBehavior.Block;
    } catch (e, stackTrace) {
      checkerEvent.performPhase3MappingTest = EventState.error;
      updateCheckerEvent();
      rethrow;
    }
  }

  Future<NatFilteringBehavior> _performPhase1FilteringTest() async {
    try {
      checkerEvent.performPhase1FilteringTest = EventState.running;
      updateCheckerEvent();
      // 4）客户端A以IP_CA: PORT_CA给STUN server的IP_SA: PORT_SA发送一个bind请求（请求中带CHANGE-REQUEST attribute来要求stun server改变IP和PORT来响应），STUN server以IP_SB: PORT_SB给客户端A的IP_CA: PORT_CA回复响应。
      // 如果客户端A能收到STUN server的响应，那么NAT是Endpoint-Independent Filtering的过滤规则，也就是只要给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据都能通过NAT到达客户端A的IP_CA: PORT_CA（这种过滤规则的NAT估计很少）。
      // 如果不能收到STUN server的响应，那么需要进行下面的第五步测试。
      StunMessage message = await _stunClient.sendAndAwait(_stunClient.createChangeStunMessage(flagChangeIp: true, flagChangePort: true), isAutoClose: true);
      checkerEvent.performPhase1FilteringTest = EventState.success;
      updateCheckerEvent();
      return NatFilteringBehavior.EndpointIndependent;
    } on TimeoutException catch (e) {
      checkerEvent.performPhase1FilteringTest = EventState.timeout;
      updateCheckerEvent();
      return _performPhase2FilteringTest();
    } catch (e, stackTrace) {
      checkerEvent.performPhase1FilteringTest = EventState.error;
      updateCheckerEvent();
      rethrow;
    }
  }

  Future<NatFilteringBehavior> _performPhase2FilteringTest() async {
    try {
      checkerEvent.performPhase2FilteringTest = EventState.running;
      updateCheckerEvent();
      // 5）客户端A以IP_CA: PORT_CA给STUN server的IP_SA: PORT_SA发送一个bind请求（请求中带CHANGE-REQUEST attribute来要求stun server改变PORT来响应），STUN server以IP_SA: PORT_SB给客户端A的IP_CA: PORT_CA回复响应。
      // 如果客户端A能收到STUN server的响应，NAT是Address-Dependent Filtering的过滤规则，也就是只要之前客户端A以IP_CA: PORT_CA给IP为IP_D的主机发送过数据，
      // 那么在NAT映射的有效期内，IP为IP_D的主机以任何端口给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据都能通过NAT到达客户端A的IP_CA: PORT_CA；
      // 如果不能收到响应，NAT是Address and Port-Dependent Filtering的过滤规则，也即是只有之前客户端A以IP_CA: PORT_CA给目的主机的IP_D: PORT_D发送过数据，
      // 那么在NAT映射的有效期内，只有以IP_D: PORT_D给客户端A的IP_CA: PORT_CA映射后的IP_MCA: PORT_MCA地址发送数据才能通过NAT到达客户端A的IP_CA: PORT_CA。
      StunMessage message = await _stunClient.sendAndAwait(_stunClient.createChangeStunMessage(flagChangeIp: false, flagChangePort: true), isAutoClose: true);
      checkerEvent.performPhase2FilteringTest = EventState.success;
      updateCheckerEvent();
      return NatFilteringBehavior.AddressDependent;
    } on TimeoutException catch (e) {
      checkerEvent.performPhase2FilteringTest = EventState.timeout;
      updateCheckerEvent();
      return NatFilteringBehavior.AddressAndPortDependent;
    } catch (e, stackTrace) {
      checkerEvent.performPhase2FilteringTest = EventState.error;
      updateCheckerEvent();
      rethrow;
    }
  }
}
