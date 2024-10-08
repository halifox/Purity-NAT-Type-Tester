import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purity_nat_type_tester/checker.dart' as checker;
import 'package:purity_nat_type_tester/checker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: 'Purity NAT Type Tester',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: lightDynamic,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: darkDynamic,
        ),
        home: const HomePage(),
      ),
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

  List<String> logs = ["[log]:======== start ========"];

  NATTestResult? mNATTestResult;

  bool isTestRunning = false;

  test() async {
    try {
      if (isTestRunning) return;
      setState(() {
        isTestRunning = true;
        mNATTestResult = null;
        logs = ["[log]:======== start ========"];
      });
      mNATTestResult = await getNatType(
        stunHost: stunHostController.text,
        stunPort: int.parse(stunPortController.text),
        sourceIp: sourceIpController.text,
        sourcePort: int.parse(sourcePortController.text),
      );
    } catch (e) {
      checker.print("======== catch ========");
      checker.print(e);
    } finally {
      setState(() {
        isTestRunning = false;
      });

      checker.print("======== finish ========");
    }
  }

  String getNATTypeMessage(NATType? type) {
    switch (type) {
      case null:
        return "";
      case NATType.unknown:
        return "Unknown: 未知";
      case NATType.blocked:
        return "Blocked: 无法通过NAT";
      case NATType.openInternet:
        return "OpenInternet: 无NAT";
      case NATType.fullCone:
        return "NAT1: Full Cone NAT: 全锥形NAT";
      case NATType.symmetricUDPFirewall:
        return "NAT4: Symmetric NAT: 对称型NAT; 并且具有UDP防火墙";
      case NATType.restrictNAT:
        return "NAT2: Address-Restricted Cone NAT: 受限锥型NAT";
      case NATType.restrictPortNAT:
        return "NAT3: Port-Restricted Cone NAT: 端口受限锥型NAT";
      case NATType.symmetricNAT:
        return "NAT4: Symmetric NAT: 对称型NAT";
      case NATType.changedAddressError:
        return "ChangedAddressError: 测试 Changed IP 和端口时遇到的错误。";
    }
  }

  String getInfo(NATTestResult? result) {
    return "type: ${getNATTypeMessage(result?.type)}\nip: ${result?.externalIp ?? ""}";
  }

  @override
  void initState() {
    checker.print = (e) {
      setState(() {
        logs.add("[log]:$e");
      });
    };

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarDividerColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarIconBrightness: Theme.of(context).colorScheme.brightness,
        statusBarColor: Colors.transparent,
        statusBarBrightness: Theme.of(context).colorScheme.brightness,
        statusBarIconBrightness: (Theme.of(context).colorScheme.brightness == Brightness.dark) ? Brightness.light : Brightness.dark, //MIUI的这个行为有异常
      ));
    }
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  width: double.infinity,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(24)),
                  child: Text(getInfo(mNATTestResult), style: Theme.of(context).textTheme.bodyLarge),
                ),
                SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(24)),
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return Text(logs[index], key: ValueKey(logs[index]));
                    },
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: stunHostController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'STUN server：提供 STUN 服务的服务器',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  controller: stunPortController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'STUN port：STUN 服务所在的端口（通常是 3478 或 5349）',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: sourceIpController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Source IP：发起 STUN 请求的客户端的 IP 地址。',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  controller: sourcePortController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Source port：发起 STUN 请求的客户端的端口。',
                  ),
                ),
                SizedBox(height: 16),
                FilledButton(
                  onPressed: isTestRunning ? null : test,
                  child: Text("RUN"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
