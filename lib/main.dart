import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purity_nat_type_tester/check_rfc_5780.dart' as rfc5780;

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
              children: [],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () async {
        rfc5780.Checker checker = rfc5780.Checker();
        var (a, b) = await checker.check();
        print(a);
        print(b);
      }),
    );
  }
}
