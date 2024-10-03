import 'package:flutter/material.dart';
import 'package:purity_nat_type_tester/checker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Purity NAT type tester',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TextEditingController stunHostController = TextEditingController(text: "stun.syncthing.net");
  late TextEditingController stunPortController = TextEditingController(text: "3478");
  late TextEditingController sourceIpController = TextEditingController(text: "0.0.0.0");
  late TextEditingController sourcePortController = TextEditingController(text: "54320");

  NATTestResult? mNATTestResult;

  bool isTestRunning = false;

  test() async {
    try {
      if (isTestRunning) return;
      setState(() {
        isTestRunning = true;
        mNATTestResult = null;
      });
      mNATTestResult = await getNatType(
        stunHost: stunHostController.text,
        stunPort: int.parse(stunPortController.text),
        sourceIp: sourceIpController.text,
        sourcePort: int.parse(sourcePortController.text),
      );
      setState(() {});
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        isTestRunning = false;
      });
    }
  }

  String getNATTypeMessage(NATType? type) {
    switch (type) {
      case null:
        return "";
      case NATType.unknown:
        return "未知";
      case NATType.blocked:
        return "无法通过NAT";
      case NATType.openInternet:
        return "无NAT";
      case NATType.fullCone:
        return "NAT1: Full Cone NAT，全锥形NAT";
      case NATType.symmetricUDPFirewall:
        return "NAT4: Symmetric NAT，对称型NAT; 并且具有UDP防火墙";
      case NATType.restrictNAT:
        return "NAT2: Address-Restricted Cone NAT，受限锥型NAT";
      case NATType.restrictPortNAT:
        return "NAT3: Port-Restricted Cone NAT，端口受限锥型";
      case NATType.symmetricNAT:
        return "NAT4: Symmetric NAT，对称型NAT";
      case NATType.changedAddressError:
        return "测试 Changed IP 和端口时遇到的错误。";
    }
  }

  String getInfo(NATTestResult? result) {
    return "type: ${getNATTypeMessage(result?.type)}\nip: ${result?.externalIp ?? ""}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                width: double.infinity,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(24)),
                child: Text(getInfo(mNATTestResult), style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: stunHostController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'stun host',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: stunPortController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'stun port',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: sourceIpController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'source ip',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: sourcePortController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'source port',
                ),
              ),
            ),
            FilledButton(
              onPressed: isTestRunning ? null : test,
              child: Text("测试"),
            )
          ],
        ),
      ),
    );
  }
}
