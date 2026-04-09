import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/toast_utils.dart';

class BleConfigTab extends StatefulWidget {
  const BleConfigTab({super.key});

  @override
  State<BleConfigTab> createState() => _BleConfigTabState();
}

class _BleConfigTabState extends State<BleConfigTab> {
  final _targetSsidController = TextEditingController();
  final _targetPasswordController = TextEditingController();

  bool _isScanning = false;
  bool _isConnected = false;
  bool _isLoading = false;
  String _responseMessage = '';
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _configCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<BluetoothDeviceState>? _deviceStateSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  Timer? _scanTimeoutTimer;

  // UUID для ESP32 BLE сервиса
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _listenToBluetoothState();
  }

  void _listenToBluetoothState() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;

      if (state == BluetoothAdapterState.off) {
        setState(() {
          _isScanning = false;
          _isConnected = false;
          _scanResults.clear();
          _responseMessage =
              'Bluetooth выключен. Включите Bluetooth для поиска устройств.';
        });
      } else if (state == BluetoothAdapterState.on) {
        setState(() {
          if (_responseMessage.contains('Bluetooth выключен')) {
            _responseMessage =
                'Bluetooth включен. Нажмите "Найти ESP32" для поиска.';
          }
        });
      }
    });
  }

  Future<void> _initBluetooth() async {
    if (!mounted) return;

    try {
      if (await FlutterBluePlus.isSupported == false) {
        ToastUtils.showError('BLE не поддерживается на этом устройстве');
        return;
      }

      // Проверяем состояние Bluetooth
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        setState(() {
          _responseMessage =
              'Bluetooth выключен. Включите Bluetooth для поиска устройств.';
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Ошибка BLE: $e');
      }
    }
  }

  Future<bool> _checkAndRequestBluetooth() async {
    // Проверяем текущее состояние
    final adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState == BluetoothAdapterState.on) {
      return true;
    }

    // Показываем диалог запроса включения Bluetooth
    final shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth, color: Colors.blue),
            SizedBox(width: 8),
            Text('Включить?'),
          ],
        ),
        content: const Text(
          'Для поиска ESP32 устройств необходимо включить Bluetooth.\n\n'
          'Разрешить приложению включить Bluetooth?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Включить'),
          ),
        ],
      ),
    );

    if (shouldEnable != true) {
      ToastUtils.showWarning('Bluetooth необходим для поиска устройств');
      return false;
    }

    // Пытаемся включить Bluetooth
    try {
      setState(() {
        _responseMessage = 'Включение Bluetooth...';
      });

      await FlutterBluePlus.turnOn();

      // Ждем включения
      await Future.delayed(const Duration(seconds: 2));

      final newState = await FlutterBluePlus.adapterState.first;
      if (newState == BluetoothAdapterState.on) {
        ToastUtils.showSuccess('Bluetooth включен');
        return true;
      } else {
        ToastUtils.showError('Не удалось включить Bluetooth');
        return false;
      }
    } catch (e) {
      ToastUtils.showError('Ошибка включения Bluetooth: $e');
      return false;
    }
  }

  Future<void> _startScan() async {
    if (!mounted) return;

    // Проверяем Bluetooth перед сканированием
    final bluetoothEnabled = await _checkAndRequestBluetooth();
    if (!bluetoothEnabled) {
      setState(() {
        _responseMessage =
            'Bluetooth выключен. Нажмите "Найти ESP32" и разрешите включение.';
      });
      return;
    }

    // Останавливаем предыдущее сканирование
    await _stopScan();

    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _responseMessage = 'Поиск ESP32 устройств...';
    });

    try {
      // Подписываемся на результаты сканирования
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _scanResults = results;
            if (results.isNotEmpty) {
              _responseMessage = 'Найдено ${_scanResults.length} устройств';
            }
          });
        }
      });

      // Запускаем сканирование
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      // Устанавливаем таймаут для остановки сканирования
      _scanTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _isScanning) {
          _stopScan();
          setState(() {
            if (_scanResults.isEmpty) {
              _responseMessage =
                  'Устройства не найдены. Убедитесь что ESP32 включен и загружен BLE скетч';
            } else {
              _responseMessage =
                  'Сканирование завершено. Найдено ${_scanResults.length} устройств';
            }
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _responseMessage = 'Ошибка сканирования: $e';
        });
        ToastUtils.showError('Ошибка: $e');
      }
    }
  }

  Future<void> _stopScan() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Игнорируем ошибки
    }

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    if (!mounted) return;

    // Снова проверяем Bluetooth перед подключением
    final bluetoothEnabled = await _checkAndRequestBluetooth();
    if (!bluetoothEnabled) {
      ToastUtils.showError('Bluetooth выключен, подключение невозможно');
      return;
    }

    // Останавливаем сканирование перед подключением
    await _stopScan();

    final device = result.device;

    setState(() {
      _isLoading = true;
      _responseMessage =
          'Подключение к ${device.platformName.isNotEmpty ? device.platformName : 'ESP32'}...';
    });

    try {
      // Отменяем старые подписки
      await _deviceStateSubscription?.cancel();

      // Подписываемся на состояние устройства
      _deviceStateSubscription =
          device.state.listen((state) {
                if (mounted) {
                  setState(() {
                    _isConnected = (state == BluetoothDeviceState.connected);
                  });
                }
              })
              as StreamSubscription<BluetoothDeviceState>?;

      // Подключаемся
      await device.connect(timeout: const Duration(seconds: 10));

      if (!mounted) {
        await device.disconnect();
        return;
      }

      // Ищем сервисы
      final services = await device.discoverServices();

      bool found = false;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            SERVICE_UUID.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                CHARACTERISTIC_UUID.toLowerCase()) {
              if (mounted) {
                setState(() {
                  _configCharacteristic = characteristic;
                  _connectedDevice = device;
                  _responseMessage =
                      'Подключено к ${device.platformName.isNotEmpty ? device.platformName : 'ESP32'}';
                });
                ToastUtils.showSuccess('Подключено к ESP32');
              }
              found = true;
              break;
            }
          }
        }
        if (found) break;
      }

      if (!found && mounted) {
        await device.disconnect();
        setState(() {
          _responseMessage =
              'Сервис конфигурации не найден. Убедитесь что загружен правильный скетч';
        });
        ToastUtils.showError('ESP32 не поддерживает конфигурацию');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _responseMessage = 'Ошибка подключения: $e';
        });
        ToastUtils.showError('Ошибка: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendConfig() async {
    if (!mounted) return;

    if (!_isConnected || _connectedDevice == null) {
      ToastUtils.showError('Сначала подключитесь к ESP32');
      return;
    }

    final ssid = _targetSsidController.text.trim();
    if (ssid.isEmpty) {
      ToastUtils.showError('Введите SSID Wi-Fi сети');
      return;
    }

    setState(() {
      _isLoading = true;
      _responseMessage = 'Отправка конфигурации...';
    });

    try {
      final password = _targetPasswordController.text.trim();
      final data = "$ssid|$password";
      final bytes = data.codeUnits;

      await _configCharacteristic?.write(bytes);

      if (mounted) {
        setState(() {
          _responseMessage =
              '✅ Конфигурация отправлена успешно! ESP32 перезагружается...';
          _isLoading = false;
        });
        ToastUtils.showSuccess('Настройки отправлены на ESP32');

        await Future.delayed(const Duration(seconds: 2));
        await _connectedDevice?.disconnect();

        if (mounted) {
          setState(() {
            _isConnected = false;
            _connectedDevice = null;
            _configCharacteristic = null;
          });
        }

        _targetSsidController.clear();
        _targetPasswordController.clear();
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

  void _disconnect() async {
    await _connectedDevice?.disconnect();
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (mounted) {
      setState(() {
        _isConnected = false;
        _connectedDevice = null;
        _configCharacteristic = null;
        _responseMessage = 'Отключено';
      });
      ToastUtils.showInfo('Отключено от ESP32');
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;

    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;

    _scanSubscription?.cancel();
    _scanSubscription = null;

    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;

    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    _connectedDevice?.disconnect();
    _connectedDevice = null;

    FlutterBluePlus.stopScan().catchError((e) {});

    _targetSsidController.dispose();
    _targetPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Статус BLE
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                    color: _isConnected ? Colors.green : Colors.blue,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? 'Подключено к ESP32' : 'BLE режим',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isConnected ? Colors.green : Colors.blue,
                          ),
                        ),
                        if (_isConnected && _connectedDevice != null)
                          Text(
                            _connectedDevice!.platformName.isNotEmpty
                                ? _connectedDevice!.platformName
                                : 'ESP32 устройство',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (!_isConnected)
                          const Text(
                            'Нажмите "Найти ESP32" для поиска устройств',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (!_isConnected)
                    ElevatedButton.icon(
                      onPressed: _isScanning ? null : _startScan,
                      icon: Icon(_isScanning ? Icons.stop : Icons.search),
                      label: Text(_isScanning ? 'Поиск...' : 'Найти ESP32'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Список найденных устройств
            if (_scanResults.isNotEmpty && !_isConnected)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Найденные устройства:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._scanResults.map(
                        (result) => ListTile(
                          leading: const Icon(
                            Icons.bluetooth,
                            color: Colors.blue,
                          ),
                          title: Text(
                            result.device.platformName.isNotEmpty
                                ? result.device.platformName
                                : 'ESP32 устройство',
                          ),
                          subtitle: Text(result.device.remoteId.toString()),
                          trailing: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _connectToDevice(result),
                            child: const Text('Подключиться'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Настройки Wi-Fi
            const Text(
              'Настройки вашего Wi-Fi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetSsidController,
              decoration: const InputDecoration(
                labelText: 'SSID вашего роутера',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.router),
              ),
              enabled: _isConnected,
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
              enabled: _isConnected,
            ),
            const SizedBox(height: 24),

            // Кнопка отправки
            ElevatedButton.icon(
              onPressed: (!_isConnected || _isLoading) ? null : _sendConfig,
              icon: const Icon(Icons.send),
              label: const Text('Отправить настройки на ESP32'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
            ),

            if (_isConnected)
              TextButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Отключиться'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            const SizedBox(height: 16),

            // Сообщение о статусе
            if (_responseMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _responseMessage.contains('✅')
                      ? Colors.green.shade50
                      : (_responseMessage.contains('❌')
                            ? Colors.red.shade50
                            : Colors.blue.shade50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _responseMessage.contains('✅')
                          ? Icons.check_circle
                          : (_responseMessage.contains('❌')
                                ? Icons.error
                                : Icons.info),
                      color: _responseMessage.contains('✅')
                          ? Colors.green
                          : (_responseMessage.contains('❌')
                                ? Colors.red
                                : Colors.blue),
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 Инструкция для BLE режима:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Загрузите BLE скетч на ESP32 (см. вкладку "Помощь")',
                  ),
                  Text('2. Включите Bluetooth на телефоне'),
                  Text('3. Нажмите "Найти ESP32" (поиск идет 15 секунд)'),
                  Text('4. Выберите ваше устройство из списка'),
                  Text('5. Введите SSID и пароль вашего Wi-Fi'),
                  Text('6. Нажмите "Отправить настройки"'),
                  Text('7. ESP32 подключится к вашему Wi-Fi'),
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
