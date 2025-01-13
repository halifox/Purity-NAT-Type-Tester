import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purity_nat_type_tester/checker_event.dart';

import 'event_bus.dart';
import 'nat_checker_rfc_5780.dart';

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
  final String pattern = r'^([a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+):([1-9][0-9]{0,4})$';
  TextEditingController stunController = TextEditingController(text: "stun.hot-chilli.net:3478");

  NatMappingBehavior? natMappingBehavior;
  NatFilteringBehavior? natFilteringBehavior;

  CheckerEvent event = CheckerEvent();
  bool isRunning = false;

  String get natMappingBehaviorMessage {
    return switch (natMappingBehavior) {
      null => "等待",
      NatMappingBehavior.Block => "Block",
      NatMappingBehavior.EndpointIndependent => "Endpoint-Independent Mapping",
      NatMappingBehavior.AddressDependent => "Address and Port-Dependent Mapping",
      NatMappingBehavior.AddressAndPortDependent => "Address-Dependent Mapping",
    };
  }

  String get natFilteringBehaviorMessage {
    return switch (natFilteringBehavior) {
      null => "等待",
      NatFilteringBehavior.Block => "Block",
      NatFilteringBehavior.EndpointIndependent => "Endpoint-Independent Filtering",
      NatFilteringBehavior.AddressDependent => "Address and Port-Dependent Filtering",
      NatFilteringBehavior.AddressAndPortDependent => "Address-Dependent Filtering",
    };
  }

  String get rfc3489Message {
    if (natMappingBehavior == NatMappingBehavior.EndpointIndependent && natFilteringBehavior == NatFilteringBehavior.EndpointIndependent) {
      return "对应于RFC3489中的Full Cone NAT";
    }
    if (natMappingBehavior == NatMappingBehavior.EndpointIndependent && natFilteringBehavior == NatFilteringBehavior.AddressDependent) {
      return "对应于RFC3489中的Restricted Cone NAT";
    }
    if (natMappingBehavior == NatMappingBehavior.EndpointIndependent && natFilteringBehavior == NatFilteringBehavior.AddressAndPortDependent) {
      return "对应于RFC3489中的Port Restricted Cone NAT";
    }
    if (natMappingBehavior == NatMappingBehavior.AddressAndPortDependent && natFilteringBehavior == NatFilteringBehavior.AddressAndPortDependent) {
      return "对应于RFC3489中的Symmetric NAT";
    }
    return "不对应于RFC3489中任何类型;RFC3489只描述了9种NAT组合行为类型中的4种。";
  }

  String get message {
    return switch (event.result) {
      EventState.idle => "等待",
      EventState.running => "运行中",
      EventState.success => "结果:\n映射规则:${natMappingBehaviorMessage}\n过滤规则:${natFilteringBehaviorMessage}\n${rfc3489Message}",
      EventState.timeout => "超时",
      EventState.error => "错误",
      EventState.never => "异常",
    };
  }

  @override
  void initState() {
    bus.stream.listen((event) {
      if (event is CheckerEvent) {
        setState(() {
          this.event = event;
        });
      }
    });
    super.initState();
  }

  Widget StateIcon(EventState state) {
    return switch (state) {
      EventState.idle => Icon(Icons.trip_origin),
      EventState.running => Icon(Icons.timelapse),
      EventState.success => Icon(Icons.check),
      EventState.timeout => Icon(Icons.running_with_errors),
      EventState.error => Icon(Icons.error_outline),
      EventState.never => Icon(Icons.block),
    };
  }

  Widget StateItem(EventState state, String message) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: state == EventState.idle ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Row(
          children: [
            StateIcon(state),
            SizedBox(width: 8),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
      ),
    );
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StateItem(event.result, message),
                StateItem(event.initializeLocalAddresses, "本机网络接口检测"),
                StateItem(event.performPhase1MappingTest, "本地公网地址检测"),
                StateItem(event.performPhase2MappingTest, "独立端点映射检测"),
                StateItem(event.performPhase3MappingTest, "地址依赖映射检测"),
                StateItem(event.performPhase1FilteringTest, "独立端点过滤检测"),
                StateItem(event.performPhase2FilteringTest, "地址依赖过滤检测"),
                SizedBox(height: 8),
                buildStunEditText(),
                buildStunChipGroup(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(isRunning ? Icons.timelapse : Icons.play_arrow),
        label: Text(isRunning ? "等待结果" : "开始检查"),
        onPressed: startCheck,
      ),
    );
  }

  void startCheck() async {
    if (isRunning) return;
    try {
      setState(() {
        isRunning = true;
      });
      checkerEvent.clear();
      updateCheckerEvent();

      String input = stunController.text;

      RegExpMatch? match = RegExp(pattern).firstMatch(input);
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("STUN 输入错误")));
        return;
      }

      String host = match.group(1)!;
      int port = int.parse(match.group(3) ?? "3478");
      NatChecker checker = NatChecker(
        serverHost: host,
        serverPort: port,
      );
      var (natMappingBehavior, natFilteringBehavior) = await checker.check();
      setState(() {
        this.natMappingBehavior = natMappingBehavior;
        this.natFilteringBehavior = natFilteringBehavior;
      });
    } catch (e) {
      showErrorDialog(context, "${e}");
    } finally {
      setState(() {
        isRunning = false;
      });
    }
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("error"),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("back"),
            ),
          ],
        );
      },
    );
  }

  Widget buildStunEditText() {
    return TextField(
      controller: stunController,
      decoration: InputDecoration(
        labelText: "STUN",
        border: const OutlineInputBorder(
          borderSide: BorderSide(),
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          gapPadding: 8.0,
        ),
      ),
    );
  }

  Widget buildStunChipGroup() {
    return Wrap(
      children: [
        buildStunChip("stun.hot-chilli.net:3478"),
        buildStunChip("stun.l.google.com:19302"),
        buildStunChip("stun.stunprotocol.org:3478"),
        buildStunChip("stun.ekiga.net:3478"),
        buildStunChip("stun.sipgate.net:3478"),
        buildStunChip("stun.xten.com:3478"),
        buildStunChip("stun.voipbuster.com:3478"),
      ],
    );
  }

  Widget buildStunChip(String server) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 8, 0),
      child: ActionChip(
        label: Text(server),
        onPressed: () {
          stunController.text = server;
        },
      ),
    );
  }
}
