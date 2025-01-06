import 'package:stun/src/stun_message_rfc5389.dart' as rfc5389;
import 'package:stun/src/stun_message_rfc5780.dart' as rfc5780;
import 'package:stun/stun.dart';

main() async {}

a() async {
  StunClient stunClient = StunClient.create(
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

  if (xorMappedAddressAttribute1.address == "0.0.0.0" /*?!*/ && xorMappedAddressAttribute1.port == 3478) {
    //它没有经过 NAT，且有效映射将是端点独立的。
    //Endpoint-Independent Mapping
    return;
  }

  StunClient stunClient2 = StunClient.create(
    transport: Transport.udp,
    serverHost: otherAddress1.addressDisplayName!,
    serverPort: 3478,
    localIp: "0.0.0.0",
    localPort: 54320,
    stunProtocol: StunProtocol.RFC5780,
  );

  StunMessage message2 = await stunClient2.send(stunClient.createBindingStunMessage());
  var xorMappedAddressAttribute2 = message2.attributes.firstWhere((e) => e.type == StunAttributes.TYPE_XOR_MAPPED_ADDRESS) as rfc5389.XorMappedAddressAttribute;
  if (xorMappedAddressAttribute2.address == xorMappedAddressAttribute1.address && xorMappedAddressAttribute2.port == xorMappedAddressAttribute1.port) {
    //当前 NAT 具有端点独立映射
    //Endpoint-Independent Mapping
    return;
  }
  StunClient stunClient3 = StunClient.create(
    transport: Transport.udp,
    serverHost: otherAddress1.addressDisplayName!,
    serverPort: otherAddress1.port,
    localIp: "0.0.0.0",
    localPort: 54320,
    stunProtocol: StunProtocol.RFC5780,
  );

  StunMessage message3 = await stunClient3.send(stunClient.createBindingStunMessage());
  var xorMappedAddressAttribute3 = message3.attributes.firstWhere((e) => e.type == StunAttributes.TYPE_XOR_MAPPED_ADDRESS) as rfc5389.XorMappedAddressAttribute;
  if (xorMappedAddressAttribute2.address == xorMappedAddressAttribute3.address && xorMappedAddressAttribute2.port == xorMappedAddressAttribute3.port) {
    //具有地址依赖映射
    //Address-Dependent Mapping
    return;
  } else {
    //地址和端口依赖映射
    //Address and Port-Dependent Mapping
    return;
  }
}

b()async{
  StunClient stunClient = StunClient.create(
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



  StunClient stunClient2 = StunClient.create(
    transport: Transport.udp,
    serverHost: otherAddress1.addressDisplayName!,
    serverPort: 3478,
    localIp: "0.0.0.0",
    localPort: 54320,
    stunProtocol: StunProtocol.RFC5780,
  );

  var createBindingStunMessage2 = stunClient.createBindingStunMessage();
  createBindingStunMessage2.attributes.add(rfc5780.ChangeRequest(StunAttributes.TYPE_CHANGE_REQUEST,8,true,true));
  StunMessage message2 = await stunClient2.send(createBindingStunMessage2);

  //Endpoint-Independent Filtering

  //:::::: timeout
  var createBindingStunMessage3 = stunClient.createBindingStunMessage();
  createBindingStunMessage3.attributes.add(rfc5780.ChangeRequest(StunAttributes.TYPE_CHANGE_REQUEST,8,true,true));
  StunMessage message3 = await stunClient2.send(createBindingStunMessage3);
  //Address-Dependent


  //::::::: timeout
  //Address and Port-Dependent Filtering.
}
