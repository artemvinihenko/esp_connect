import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/wifi_service.dart';
import '../services/wifi_scan_service.dart';
import '../utils/toast_utils.dart';

class APConfigTab extends StatefulWidget {
  const APConfigTab({super.key});

  @override
  State<APConfigTab> createState() => _APConfigTabState();
}

class _APConfigTabState extends State<APConfigTab> {
  final _deviceIpController = TextEditingController(text: '192.168.4.1');
  final _targetSsidController = TextEditingController();
  final _targetPasswordController = TextEditingController();
  final _portController = TextEditingController(text: '80');
  
  bool _isConnected = false;
  bool _isLoading = false;
  String _responseMessage = '';
  String _currentSsid = '';
  Timer? _connectionCheckTimer;
  
  @override
  void initState() {
    super.initState();
    _checkCurrentConnection();
    
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _checkCurrentConnection();
      } else {
        timer.cancel();
      }
    });
  }
  
  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _deviceIpController.dispose();
    _targetSsidController.dispose();
    _targetPasswordController.dispose();
    _portController.dispose();
    super.dispose();
  }
  
  Future<void> _checkCurrentConnection() async {
    final ssid = await WifiService.getCurrentSSID();
    if (ssid != null && ssid.isNotEmpty && ssid != 'null') {
      setState(() {
        _currentSsid = ssid;
        // Проверяем, подключены ли к ESP (SSID обычно начинается с ESP_)
        _isConnected = ssid.contains('ESP_') || ssid.contains('esp_');
      });
    } else {
      setState(() {
        _currentSsid = '';
        _isConnected = false;
      });
    }
  }
  
  Future<void> _openWifiSettings() async {
    await WifiService.openWifiSettings();
    ToastUtils.showInfo('Подключитесь к Wi-Fi сети ESP, затем вернитесь в приложение');
  }
  
  Future<void> _selectWifiNetwork() async {
    // Сканируем сети
    setState(() {
      _isLoading = true;
    });
    
    final networks = await WifiScanHelper.scanNetworks();
    
    setState(() {
      _isLoading = false;
    });
    
    if (networks.isEmpty) {
      ToastUtils.showError('Нет доступных Wi-Fi сетей');
      return;
    }
    
    // Показываем диалог выбора сети
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Выберите Wi-Fi сеть',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: networks.length,
                    itemBuilder: (context, index) {
                      final network = networks[index];
                      return ListTile(
                        leading: Icon(
                          network.secured ? Icons.lock : Icons.lock_open,
                          color: network.secured ? Colors.grey : Colors.green,
                        ),
                        title: Text(
                          network.ssid,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text('Сигнал: ${network.signalStrength}%'),
                        trailing: Icon(
                          Icons.wifi,
                          color: _getSignalColor(network.signalStrength),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          if (network.secured) {
                            _showPasswordDialog(network.ssid);
                          } else {
                            setState(() {
                              _targetSsidController.text = network.ssid;
                              _targetPasswordController.clear();
                            });
                            ToastUtils.showSuccess('Выбрана сеть: ${network.ssid}');
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }
  
  void _showPasswordDialog(String ssid) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Пароль для $ssid'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Пароль',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            setState(() {
              _targetSsidController.text = ssid;
              _targetPasswordController.text = passwordController.text;
            });
            Navigator.pop(context);
            ToastUtils.showSuccess('Выбрана сеть: $ssid');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _targetSsidController.text = ssid;
                _targetPasswordController.text = passwordController.text;
              });
              Navigator.pop(context);
              ToastUtils.showSuccess('Выбрана сеть: $ssid');
            },
            child: const Text('Выбрать'),
          ),
        ],
      ),
    );
  }
  
  Color _getSignalColor(int strength) {
    if (strength >= 70) return Colors.green;
    if (strength >= 40) return Colors.orange;
    return Colors.red;
  }
  
  Future<void> _sendConfig() async {
    if (!_isConnected) {
      ToastUtils.showError('Сначала подключитесь к Wi-Fi сети ESP');
      _openWifiSettings();
      return;
    }
    
    final ssid = _targetSsidController.text.trim();
    if (ssid.isEmpty) {
      ToastUtils.showError('Выберите Wi-Fi сеть для ESP');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _responseMessage = 'Отправка конфигурации на ESP...';
    });
    
    try {
      final configData = {
        'ssid': ssid,
        'password': _targetPasswordController.text.trim(),
      };
      
      final url = Uri.parse('http://${_deviceIpController.text}:${_portController.text}/config');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(configData),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _responseMessage = '✅ Конфигурация отправлена успешно! ESP перезагружается...';
          _isLoading = false;
        });
        ToastUtils.showSuccess('Настройки отправлены на ESP');
        
        // Очищаем поля
        _targetSsidController.clear();
        _targetPasswordController.clear();
      } else if (mounted) {
        setState(() {
          _responseMessage = '❌ Ошибка ${response.statusCode}: ${response.body}';
          _isLoading = false;
        });
        ToastUtils.showError('Ошибка отправки');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _responseMessage = '❌ Ошибка: $e';
          _isLoading = false;
        });
        ToastUtils.showError('Ошибка: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Статус подключения к ESP
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? '✅ Подключено к ESP' : '⚠️ Не подключено к ESP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isConnected ? Colors.green : Colors.orange,
                          ),
                        ),
                        if (_currentSsid.isNotEmpty)
                          Text(
                            'Сеть: $_currentSsid',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (!_isConnected)
                          const Text(
                            'Нажмите кнопку "Настройки Wi-Fi"',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openWifiSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Настройки Wi-Fi'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Настройки ESP
            const Text(
              'Настройки ESP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deviceIpController,
              decoration: const InputDecoration(
                labelText: 'IP адрес ESP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
                helperText: 'Обычно 192.168.4.1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Порт',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
                helperText: 'Обычно 80',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            
            // Выбор Wi-Fi сети для ESP
            const Text(
              'Ваша Wi-Fi сеть',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetSsidController,
                    decoration: const InputDecoration(
                      labelText: 'SSID вашего роутера',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.router),
                    ),
                    readOnly: true,
                    enabled: false,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _selectWifiNetwork,
                  icon: const Icon(Icons.search),
                  label: const Text('Выбрать'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetPasswordController,
              decoration: const InputDecoration(
                labelText: 'Пароль от Wi-Fi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            
            // Кнопка отправки
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendConfig,
              icon: const Icon(Icons.send),
              label: const Text('Отправить настройки на ESP'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            // Сообщение о статусе
            if (_responseMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _responseMessage.contains('✅') ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _responseMessage.contains('✅') ? Icons.check_circle : Icons.error,
                      color: _responseMessage.contains('✅') ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_responseMessage)),
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            
            // Инструкция
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '📱 Инструкция:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Включите ESP (должен мигать)'),
                  Text('2. Нажмите "Настройки Wi-Fi"'),
                  Text('3. Подключитесь к сети ESP (обычно ESP_Config)'),
                  Text('4. Вернитесь в приложение'),
                  Text('5. Нажмите "Выбрать" и выберите ваш домашний Wi-Fi'),
                  Text('6. Введите пароль от Wi-Fi'),
                  Text('7. Нажмите "Отправить настройки на ESP"'),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}