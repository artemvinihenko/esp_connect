import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/smart_config_tab.dart';
import 'screens/ap_config_tab.dart';
import 'screens/help_tab.dart';
import 'utils/toast_utils.dart';



void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Добавьте эту строку
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
      home: const MainTabView(),
      debugShowCheckedModeBanner: false, // Убирает баннер Debug
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _tabController = TabController(length: 3, vsync: this);
    ToastUtils.setScaffoldKey(_scaffoldKey);
    await _requestPermissions();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _requestPermissions() async {
    try {
      // Запрашиваем разрешения последовательно
      await Permission.location.request();
      await Permission.nearbyWifiDevices.request();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        key: _scaffoldKey,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка...'),
            ],
          ),
        ),
      );
    }

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