import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP Config',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainTabView(),
    );
  }
}

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.nearbyWifiDevices.request();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP Конфигуратор'),
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
        children: const [SmartConfigTab(), APConfigTab(), HelpTab()],
      ),
    );
  }
}

// Вкладка SmartConfig
class SmartConfigTab extends StatefulWidget {
  const SmartConfigTab({super.key});

  @override
  State<SmartConfigTab> createState() => _SmartConfigTabState();
}

class _SmartConfigTabState extends State<SmartConfigTab> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isConfiguring = false;
  String _statusMessage = '';

  late Provisioner _provisioner;
  String? _connectedDeviceBssid;

  @override
  void initState() {
    super.initState();
    _loadCurrentWifi();
    _initProvisioner();
  }

  void _initProvisioner() {
    _provisioner = Provisioner.espTouch();

    _provisioner.listen((response) {
      setState(() {
        _connectedDeviceBssid = response.bssidText;
        _statusMessage =
            'Устройство ${response.bssidText} подключилось к Wi-Fi!';
        _isConfiguring = false;
      });
      _showToast('Устройство успешно настроено! MAC: ${response.bssidText}');
    });
  }

  Future<void> _loadCurrentWifi() async {
    try {
      final currentWifi = await WiFiForIoTPlugin.getSSID();
      if (currentWifi != null && currentWifi.isNotEmpty) {
        _ssidController.text = currentWifi.replaceAll('"', '');
      }
    } catch (e) {
      debugPrint('Ошибка загрузки Wi-Fi: $e');
    }
  }

  Future<void> _startSmartConfig() async {
    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      _showToast('Введите SSID и пароль');
      return;
    }

    setState(() {
      _isConfiguring = true;
      _statusMessage = 'Запуск SmartConfig... Ожидание подключения устройства';
      _connectedDeviceBssid = null;
    });

    try {
      final request = ProvisioningRequest.fromStrings(
        ssid: _ssidController.text,
        password: _passwordController.text,
      );

      await _provisioner.start(request);

      await Future.delayed(const Duration(seconds: 60));

      if (_connectedDeviceBssid == null && mounted) {
        setState(() {
          _statusMessage =
              'Время ожидания истекло. Убедитесь, что ESP в режиме SmartConfig';
          _isConfiguring = false;
        });
        _showToast('Время ожидания истекло');
      }
    } catch (e, s) {
      debugPrint('Ошибка: $e\n$s');
      setState(() {
        _statusMessage = 'Ошибка: $e';
        _isConfiguring = false;
      });
      _showToast('Ошибка: $e');
    }
  }

  void _stopSmartConfig() {
    _provisioner.stop();
    setState(() {
      _isConfiguring = false;
      _statusMessage = 'SmartConfig остановлен';
    });
    _showToast('SmartConfig остановлен');
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _provisioner.stop();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi SSID',
                      prefixIcon: Icon(Icons.wifi),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi пароль',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isConfiguring ? null : _startSmartConfig,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Запустить SmartConfig'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isConfiguring ? _stopSmartConfig : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Остановить'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_statusMessage.isNotEmpty)
            Card(
              color: _connectedDeviceBssid != null
                  ? Colors.green.shade50
                  : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (_isConfiguring && _connectedDeviceBssid == null)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_connectedDeviceBssid != null)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else
                      const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              // Переключаемся на вкладку помощи с SmartConfig кодом
              final tabController = DefaultTabController.of(context);
              if (tabController != null) {
                tabController.animateTo(2);
              }
            },
            icon: const Icon(Icons.code),
            label: const Text(
              'Нужен пример кода для ESP? Смотри вкладку "Помощь"',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

// Вкладка AP режим
class APConfigTab extends StatefulWidget {
  const APConfigTab({super.key});

  @override
  State<APConfigTab> createState() => _APConfigTabState();
}

class _APConfigTabState extends State<APConfigTab> {
  final TextEditingController _deviceIpController = TextEditingController(
    text: '192.168.4.1',
  );
  final TextEditingController _apSsidController = TextEditingController();
  final TextEditingController _apPasswordController = TextEditingController();
  final TextEditingController _targetSsidController = TextEditingController();
  final TextEditingController _targetPasswordController =
      TextEditingController();
  final TextEditingController _apiPortController = TextEditingController(
    text: '80',
  );
  bool _isConnected = false;
  bool _isSending = false;
  String _responseMessage = '';

  Future<void> _connectToDeviceAP() async {
    if (_apSsidController.text.isEmpty) {
      _showToast('Введите SSID точки доступа ESP');
      return;
    }

    setState(() {
      _isSending = true;
      _responseMessage = 'Подключение к AP устройства...';
    });

    try {
      bool connected = await WiFiForIoTPlugin.connect(
        _apSsidController.text,
        password: _apPasswordController.text.isEmpty
            ? null
            : _apPasswordController.text,
        security: _apPasswordController.text.isEmpty
            ? NetworkSecurity.NONE
            : NetworkSecurity.WPA,
      );

      if (connected) {
        setState(() {
          _isConnected = true;
          _responseMessage = 'Подключено к AP устройства';
        });
        _showToast('Подключено к точке доступа');
      } else {
        setState(() {
          _responseMessage = 'Не удалось подключиться к AP';
        });
        _showToast('Ошибка подключения');
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Ошибка: $e';
      });
      _showToast('Ошибка: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _sendConfigToESP() async {
    if (!_isConnected) {
      _showToast('Сначала подключитесь к точке доступа');
      return;
    }

    if (_targetSsidController.text.isEmpty) {
      _showToast('Введите SSID Wi-Fi сети для ESP');
      return;
    }

    setState(() {
      _isSending = true;
      _responseMessage = 'Отправка конфигурации...';
    });

    try {
      final url = Uri.parse(
        'http://${_deviceIpController.text}:${_apiPortController.text}/config',
      );

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ssid': _targetSsidController.text,
              'password': _targetPasswordController.text,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _responseMessage =
              'Конфигурация отправлена успешно! Ответ: ${response.body}';
        });
        _showToast('Настройки отправлены');

        await WiFiForIoTPlugin.disconnect();
        setState(() {
          _isConnected = false;
        });
      } else {
        setState(() {
          _responseMessage =
              'Ошибка: ${response.statusCode} - ${response.body}';
        });
        _showToast('Ошибка отправки');
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Ошибка: $e';
      });
      _showToast('Ошибка: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _getDeviceStatus() async {
    if (!_isConnected) {
      _showToast('Сначала подключитесь к точке доступа');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final url = Uri.parse(
        'http://${_deviceIpController.text}:${_apiPortController.text}/status',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _responseMessage = 'Статус: ${response.body}';
        });
      } else {
        setState(() {
          _responseMessage = 'Ошибка получения статуса: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Ошибка: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _disconnectFromAP() async {
    await WiFiForIoTPlugin.disconnect();
    setState(() {
      _isConnected = false;
      _responseMessage = 'Отключено от AP';
    });
    _showToast('Отключено от точки доступа');
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  void dispose() {
    _deviceIpController.dispose();
    _apSsidController.dispose();
    _apPasswordController.dispose();
    _targetSsidController.dispose();
    _targetPasswordController.dispose();
    _apiPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _deviceIpController,
                    decoration: const InputDecoration(
                      labelText: 'IP адрес ESP в AP режиме',
                      prefixIcon: Icon(Icons.dns),
                      border: OutlineInputBorder(),
                      helperText: 'Обычно 192.168.4.1',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiPortController,
                    decoration: const InputDecoration(
                      labelText: 'Порт API сервера',
                      prefixIcon: Icon(Icons.settings_ethernet),
                      border: OutlineInputBorder(),
                      helperText: 'По умолчанию 80',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Параметры точки доступа ESP',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apSsidController,
                    decoration: const InputDecoration(
                      labelText: 'SSID точки доступа ESP',
                      prefixIcon: Icon(Icons.wifi_tethering),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Пароль точки доступа',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                      helperText: 'Оставьте пустым, если нет пароля',
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Настройки Wi-Fi для ESP',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _targetSsidController,
                    decoration: const InputDecoration(
                      labelText: 'SSID вашего роутера',
                      prefixIcon: Icon(Icons.router),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _targetPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Пароль от вашего Wi-Fi',
                      prefixIcon: Icon(Icons.vpn_key),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isConnected)
            ElevatedButton.icon(
              onPressed: _isSending ? null : _connectToDeviceAP,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Подключиться к точке доступа ESP'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSending ? null : _sendConfigToESP,
                        icon: const Icon(Icons.send),
                        label: const Text('Отправить настройки на ESP'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSending ? null : _getDeviceStatus,
                        icon: const Icon(Icons.info),
                        label: const Text('Проверить статус'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSending ? null : _disconnectFromAP,
                        icon: const Icon(Icons.close),
                        label: const Text('Отключиться'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (_responseMessage.isNotEmpty)
            Card(
              color: _responseMessage.contains('успешно')
                  ? Colors.green.shade50
                  : (_responseMessage.contains('Ошибка')
                        ? Colors.red.shade50
                        : Colors.blue.shade50),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    if (_isSending)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_responseMessage.contains('успешно'))
                      const Icon(Icons.check_circle, color: Colors.green)
                    else if (_responseMessage.contains('Ошибка'))
                      const Icon(Icons.error, color: Colors.red)
                    else
                      const Icon(Icons.message, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _responseMessage,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final tabController = DefaultTabController.of(context);
              if (tabController != null) {
                tabController.animateTo(2);
              }
            },
            icon: const Icon(Icons.code),
            label: const Text(
              'Нужен пример кода для ESP? Смотри вкладку "Помощь"',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

// Вкладка Помощь с примерами кода
class HelpTab extends StatefulWidget {
  const HelpTab({super.key});

  @override
  State<HelpTab> createState() => _HelpTabState();
}

class _HelpTabState extends State<HelpTab> with SingleTickerProviderStateMixin {
  late TabController _helpTabController;

  @override
  void initState() {
    super.initState();
    _helpTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _helpTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.blue.shade50,
          child: TabBar(
            controller: _helpTabController,
            tabs: const [
              Tab(icon: Icon(Icons.wifi_tethering), text: 'SmartConfig код'),
              Tab(icon: Icon(Icons.settings_ethernet), text: 'AP режим код'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _helpTabController,
            children: const [SmartConfigCodeExample(), APModeCodeExample()],
          ),
        ),
      ],
    );
  }
}

// Пример кода для SmartConfig
class SmartConfigCodeExample extends StatelessWidget {
  const SmartConfigCodeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Что такое SmartConfig?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SmartConfig - технология от Texas Instruments, которая позволяет передать '
                    'SSID и пароль Wi-Fi сети на ESP устройство без необходимости подключаться '
                    'к его точке доступа. Телефон отправляет данные через UDP broadcast, '
                    'ESP их перехватывает и подключается к Wi-Fi.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Код для ESP8266 (SmartConfig):',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  '''
#include <ESP8266WiFi.h>

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  
  Serial.println("Запуск SmartConfig...");
  WiFi.beginSmartConfig();
  
  while (!WiFi.smartConfigDone()) {
    delay(1000);
    Serial.print(".");
  }
  
  Serial.println("\\nSmartConfig получен");
  Serial.println("Подключение к Wi-Fi...");
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\\nПодключено к Wi-Fi!");
  Serial.print("IP адрес: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // Ваш код здесь
}''',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Код для ESP32 (SmartConfig):',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  '''
#include <WiFi.h>

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  
  Serial.println("Запуск SmartConfig...");
  WiFi.beginSmartConfig();
  
  while (!WiFi.smartConfigDone()) {
    delay(1000);
    Serial.print(".");
  }
  
  Serial.println("\\nSmartConfig получен");
  Serial.println("Подключение к Wi-Fi...");
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\\nПодключено к Wi-Fi!");
  Serial.print("IP адрес: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // Ваш код здесь
}''',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Важно:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• SmartConfig работает через broadcast и настраивает ВСЕ ESP в режиме SmartConfig в сети\n'
                    '• Для выбора конкретного устройства используйте AP режим\n'
                    '• Убедитесь, что телефон подключен к той же Wi-Fi сети, к которой хотите подключить ESP\n'
                    '• Некоторые роутеры могут блокировать broadcast - в этом случае используйте AP режим',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Пример кода для AP режима
class APModeCodeExample extends StatelessWidget {
  const APModeCodeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Что такое AP режим?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'В AP режиме ESP создает собственную Wi-Fi точку доступа. '
                    'Телефон подключается к этой точке и отправляет настройки через HTTP запросы. '
                    'Этот метод более надежен и позволяет настраивать конкретное устройство.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Код для ESP8266 (AP режим + HTTP сервер):',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  '''
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>

const char* ap_ssid = "ESP_Config";
const char* ap_password = "12345678";

ESP8266WebServer server(80);

String target_ssid = "";
String target_password = "";

void setup() {
  Serial.begin(115200);
  
  // Запускаем AP режим
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_ssid, ap_password);
  
  Serial.println("AP режим запущен");
  Serial.print("IP адрес: ");
  Serial.println(WiFi.softAPIP());
  
  // Настройка обработчиков
  server.on("/config", HTTP_POST, handleConfig);
  server.on("/status", HTTP_GET, handleStatus);
  server.onNotFound([]() {
    server.send(404, "application/json", "{\"error\":\"Not found\"}");
  });
  
  server.begin();
  Serial.println("HTTP сервер запущен");
}

void loop() {
  server.handleClient();
}

void handleConfig() {
  if (server.hasArg("plain")) {
    String body = server.arg("plain");
    DynamicJsonDocument doc(256);
    deserializeJson(doc, body);
    
    target_ssid = doc["ssid"].as<String>();
    target_password = doc["password"].as<String>();
    
    Serial.println("Получены настройки:");
    Serial.println("SSID: " + target_ssid);
    Serial.println("Password: " + target_password);
    
    // Отправляем ответ
    server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Config received\"}");
    
    // Подключаемся к Wi-Fi
    WiFi.mode(WIFI_STA);
    WiFi.begin(target_ssid.c_str(), target_password.c_str());
    
    // Ждем подключения
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(1000);
      attempts++;
      Serial.print(".");
    }
    
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\\nПодключено к Wi-Fi!");
      Serial.print("IP: ");
      Serial.println(WiFi.localIP());
    } else {
      Serial.println("\\nОшибка подключения");
    }
    
    delay(1000);
    ESP.restart();
  } else {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No body\"}");
  }
}

void handleStatus() {
  String status = WiFi.status() == WL_CONNECTED ? "connected" : "disconnected";
  String response = "{\"status\":\"" + status + "\",\"ip\":\"" + WiFi.localIP().toString() + "\"}";
  server.send(200, "application/json", response);
}''',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Код для ESP32 (AP режим + HTTP сервер):',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  '''
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>

const char* ap_ssid = "ESP_Config";
const char* ap_password = "12345678";

WebServer server(80);

String target_ssid = "";
String target_password = "";

void setup() {
  Serial.begin(115200);
  
  // Запускаем AP режим
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_ssid, ap_password);
  
  Serial.println("AP режим запущен");
  Serial.print("IP адрес: ");
  Serial.println(WiFi.softAPIP());
  
  // Настройка обработчиков
  server.on("/config", HTTP_POST, handleConfig);
  server.on("/status", HTTP_GET, handleStatus);
  server.onNotFound([]() {
    server.send(404, "application/json", "{\"error\":\"Not found\"}");
  });
  
  server.begin();
  Serial.println("HTTP сервер запущен");
}

void loop() {
  server.handleClient();
}

void handleConfig() {
  if (server.hasArg("plain")) {
    String body = server.arg("plain");
    DynamicJsonDocument doc(256);
    deserializeJson(doc, body);
    
    target_ssid = doc["ssid"].as<String>();
    target_password = doc["password"].as<String>();
    
    Serial.println("Получены настройки:");
    Serial.println("SSID: " + target_ssid);
    Serial.println("Password: " + target_password);
    
    // Отправляем ответ
    server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Config received\"}");
    
    // Подключаемся к Wi-Fi
    WiFi.mode(WIFI_STA);
    WiFi.begin(target_ssid.c_str(), target_password.c_str());
    
    // Ждем подключения
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(1000);
      attempts++;
      Serial.print(".");
    }
    
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\\nПодключено к Wi-Fi!");
      Serial.print("IP: ");
      Serial.println(WiFi.localIP());
    } else {
      Serial.println("\\nОшибка подключения");
    }
    
    delay(1000);
    ESP.restart();
  } else {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No body\"}");
  }
}

void handleStatus() {
  String status = WiFi.status() == WL_CONNECTED ? "connected" : "disconnected";
  String response = "{\"status\":\"" + status + "\",\"ip\":\"" + WiFi.localIP().toString() + "\"}";
  server.send(200, "application/json", response);
}''',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Важно:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• В AP режиме телефон должен подключиться к Wi-Fi сети ESP\n'
                    '• По умолчанию IP адрес ESP: 192.168.4.1\n'
                    '• Можно изменить SSID и пароль AP в коде\n'
                    '• ESP перезагрузится после успешной настройки\n'
                    '• Убедитесь, что в скетче установлена правильная плата (ESP8266 или ESP32)',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Библиотеки для Arduino IDE:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• ESP8266: ESP8266WiFi, ESP8266WebServer, ArduinoJson\n'
                    '• ESP32: WiFi, WebServer, ArduinoJson\n'
                    '• Установите ArduinoJson через менеджер библиотек (версия 6.x)',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
