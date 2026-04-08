import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/smart_config_tab.dart';
import 'screens/ap_config_tab.dart';
import 'screens/help_tab.dart';
import 'utils/toast_utils.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP Конфигуратор',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // iOS стиль
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const MainTabView(),
    );
  }
}

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _requestPermissions();
    ToastUtils.setScaffoldKey(_scaffoldKey);
  }

  Future<void> _requestPermissions() async {
    // Запрашиваем разрешения для разных платформ
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // Для iOS
      await Permission.locationWhenInUse.request();
      await Permission.nearbyWifiDevices.request();
    } else {
      // Для Android
      await Permission.location.request();
      await Permission.nearbyWifiDevices.request();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('ESP Конфигуратор'),
        centerTitle: true,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'SmartConfig'),
            Tab(icon: Icon(Icons.settings_ethernet), text: 'AP режим'),
            Tab(icon: Icon(Icons.help_outline), text: 'Помощь'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SmartConfigTab(),
          APConfigTab(),
          HelpTab(),
        ],
      ),
    );
  }
}