// Folder: lib/
// File:   main.dart
//
// DataCharge — All-in-One Offline Shorts/Reels Hub
// App entry point: initialises Hive, wires up providers, launches FeedScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:startapp_sdk/startapp.dart';

import 'feed_screen.dart';
import 'connectivity_service.dart';
import 'feed_provider.dart';
import 'hive_service.dart';
import 'app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialise Hive local database
  await HiveService.init();

  // Boot connectivity watcher early
  ConnectivityService.instance;

  // Initialize Start.io SDK
  var startAppSdk = StartAppSdk();
  startAppSdk.loadSdk(
    appId: "205598221",
  ).then((_) {
    startAppSdk.showBanner(StartAppBannerType.AUTOMATIC);
  }).catchError((e) {
    debugPrint("Failed to load Start.io SDK: $e");
  });

  runApp(const DataChargeApp());
}

class DataChargeApp extends StatelessWidget {
  const DataChargeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FeedProvider>(
          create: (_) => FeedProvider(),
        ),
        ChangeNotifierProvider<ConnectivityService>.value(
          value: ConnectivityService.instance,
        ),
      ],
      child: MaterialApp(
        title: 'DataCharge',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const FeedScreen(),
      ),
    );
  }
}
