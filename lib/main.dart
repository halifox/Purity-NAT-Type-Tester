import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stun/src/nat_checker_rfc_5780.dart' as rfc5780;

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

  rfc5780.NatMappingBehavior? natMappingBehavior;
  rfc5780.NatFilteringBehavior? natFilteringBehavior;

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
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${natMappingBehavior}"),
                Text("${natFilteringBehavior}"),
                buildStunEditText(),
                buildStunChipGroup(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.play_arrow),
        onPressed: () async {
          try {
            String input = stunController.text;

            RegExpMatch? match = RegExp(pattern).firstMatch(input);
            if (match == null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("STUN 输入错误")));
              return;
            }

            String host = match.group(1)!;
            int port = int.parse(match.group(3) ?? "3478");
            rfc5780.NatChecker checker = rfc5780.NatChecker(
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
          }
        },
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: stunController,
        decoration: InputDecoration(
          labelText: "STUN",
          border: const OutlineInputBorder(
            borderSide: BorderSide(),
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            gapPadding: 8.0,
          ),
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
      padding: EdgeInsets.fromLTRB(0, 8, 16, 0),
      child: ActionChip(
        label: Text(server),
        onPressed: () {
          stunController.text = server;
        },
      ),
    );
  }
}
