import 'dart:async';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:flutter/material.dart';
import '../utils/toast_utils.dart';
import '../widgets/status_card.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';

class SmartConfigTab extends StatefulWidget {
  const SmartConfigTab({super.key});

  @override
  State<SmartConfigTab> createState() => _SmartConfigTabState();
}

class _SmartConfigTabState extends State<SmartConfigTab> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  late final Provisioner _provisioner;
  StreamSubscription<ProvisioningResponse>? _subscription;

  bool _isConfiguring = false;
  bool _isLoadingWifi = true;
  String _statusMessage = '';
  String _currentSsid = '';

  // Флаг для предотвращения повторных запросов разрешений
  bool _isRequestingPermissions = false;

  @override
  void initState() {
    super.initState();
    _initProvisioner();
    _checkPermissionsAndLoadWifi();
  }

  void _initProvisioner() {
    _provisioner = Provisioner.espTouch();

    _subscription = _provisioner.listen((response) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Устройство ${response.bssidText} подключилось!';
          _isConfiguring = false;
        });
        ToastUtils.showSuccess(
          'ESP успешно настроен! MAC: ${response.bssidText}',
        );
      }
    });
  }

  Future<void> _checkPermissionsAndLoadWifi() async {
    // Предотвращаем повторные запросы
    if (_isRequestingPermissions) return;

    setState(() {
      _isLoadingWifi = true;
      _statusMessage = 'Проверка разрешений...';
    });

    _isRequestingPermissions = true;

    try {
      // Проверяем, какие разрешения уже есть
      final locationStatus = await Permission.location.status;
      final nearbyStatus = await Permission.nearbyWifiDevices.status;

      // Запрашиваем только те, которых нет
      Map<Permission, PermissionStatus> statuses = {};

      if (!locationStatus.isGranted) {
        statuses[Permission.location] = await Permission.location.request();
      }

      if (!nearbyStatus.isGranted) {
        statuses[Permission.nearbyWifiDevices] = await Permission
            .nearbyWifiDevices
            .request();
      }

      // Если разрешения получены, загружаем Wi-Fi
      if ((locationStatus.isGranted ||
              statuses[Permission.location]?.isGranted == true) ||
          (nearbyStatus.isGranted ||
              statuses[Permission.nearbyWifiDevices]?.isGranted == true)) {
        await _loadCurrentWifi();
      } else {
        setState(() {
          _isLoadingWifi = false;
          _statusMessage = 'Нет разрешения на определение Wi-Fi сети';
        });
        ToastUtils.showWarning(
          'Для автоматического определения Wi-Fi дайте разрешение',
        );
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      setState(() {
        _isLoadingWifi = false;
        _statusMessage = 'Ошибка проверки разрешений';
      });
    } finally {
      _isRequestingPermissions = false;
    }
  }

  Future<void> _loadCurrentWifi() async {
    try {
      setState(() {
        _statusMessage = 'Получение информации о Wi-Fi...';
      });

      // Включаем WiFi если выключен
      await WiFiForIoTPlugin.setEnabled(true);
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Небольшая задержка

      final ssid = await WiFiForIoTPlugin.getSSID();

      if (ssid != null && ssid.isNotEmpty && ssid != 'null' && ssid != '0x') {
        final cleanSsid = ssid.replaceAll('"', '');
        setState(() {
          _currentSsid = cleanSsid;
          _ssidController.text = cleanSsid;
          _statusMessage = 'Текущая Wi-Fi сеть: $cleanSsid';
        });
        ToastUtils.showInfo('Определена Wi-Fi сеть: $cleanSsid');
      } else {
        setState(() {
          _currentSsid = 'Не удалось определить';
          _statusMessage =
              'Не удалось определить Wi-Fi сеть. Введите SSID вручную.';
        });
        ToastUtils.showWarning('Не удалось определить Wi-Fi сеть');
      }
    } catch (e) {
      debugPrint('Error loading WiFi: $e');
      setState(() {
        _currentSsid = 'Ошибка определения';
        _statusMessage = 'Ошибка определения Wi-Fi: $e';
      });
    } finally {
      setState(() {
        _isLoadingWifi = false;
      });
    }
  }

  Future<void> _startSmartConfig() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    if (ssid.isEmpty || password.isEmpty) {
      ToastUtils.showError('Введите SSID и пароль Wi-Fi');
      return;
    }

    setState(() {
      _isConfiguring = true;
      _statusMessage =
          'Запуск SmartConfig... Ожидание подключения ESP (до 60 сек)';
    });

    try {
      final request = ProvisioningRequest.fromStrings(
        ssid: ssid,
        password: password,
      );

      await _provisioner.start(request);

      Future.delayed(const Duration(seconds: 60), () {
        if (_isConfiguring && mounted) {
          setState(() {
            _statusMessage = 'Время ожидания истекло. Проверьте ESP';
            _isConfiguring = false;
          });
          _provisioner.stop();
          ToastUtils.showWarning('Время ожидания истекло');
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Ошибка: $e';
        _isConfiguring = false;
      });
      ToastUtils.showError('Ошибка: $e');
    }
  }

  void _stopSmartConfig() {
    _provisioner.stop();
    setState(() {
      _isConfiguring = false;
      _statusMessage = 'SmartConfig остановлен';
    });
    ToastUtils.showInfo('SmartConfig остановлен');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _provisioner.stop();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentSsid.isNotEmpty && !_isLoadingWifi)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Текущее подключение:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _currentSsid,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (!_isConfiguring && !_isLoadingWifi)
                        TextButton.icon(
                          onPressed: _loadCurrentWifi,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Обновить'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildWifiInputCard(),
            const SizedBox(height: 16),
            _buildControlButtons(),
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty)
              StatusCard(
                message: _statusMessage,
                type: _isConfiguring
                    ? StatusType.info
                    : (_statusMessage.contains('успешно')
                          ? StatusType.success
                          : (_statusMessage.contains('Ошибка')
                                ? StatusType.error
                                : StatusType.info)),
                isLoading: _isConfiguring || _isLoadingWifi,
              ),
            const Spacer(),
            _buildHintCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ssidController,
              decoration: InputDecoration(
                labelText: 'Wi-Fi SSID',
                prefixIcon: const Icon(Icons.wifi),
                border: const OutlineInputBorder(),
                helperText: _isLoadingWifi
                    ? 'Определение текущей сети...'
                    : null,
                suffixIcon: !_isConfiguring && !_isLoadingWifi
                    ? IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadCurrentWifi,
                        tooltip: 'Определить текущую Wi-Fi сеть',
                      )
                    : null,
              ),
              enabled: !_isConfiguring,
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
              enabled: !_isConfiguring,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (_isConfiguring || _isLoadingWifi)
                ? null
                : _startSmartConfig,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Запустить'),
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
    );
  }

  Widget _buildHintCard() {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '📱 Инструкция:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Подключитесь к Wi-Fi сети (2.4 GHz)'),
            Text('2. Нажмите "Обновить" для определения сети'),
            Text('3. Введите пароль от Wi-Fi'),
            Text('4. Нажмите "Запустить"'),
            Text('5. Включите ESP в режим SmartConfig'),
            Text('6. Дождитесь подключения (до 60 сек)'),
            SizedBox(height: 8),
            Text(
              'ℹ️ SmartConfig настраивает ВСЕ ESP в сети',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
