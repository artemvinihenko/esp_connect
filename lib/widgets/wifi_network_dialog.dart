import 'package:flutter/material.dart';
import '../services/wifi_scan_service.dart';


class WifiNetworkDialog extends StatelessWidget {
  final Function(String ssid, String? password) onNetworkSelected;
  
  const WifiNetworkDialog({
    super.key,
    required this.onNetworkSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Row(
        children: [
          Icon(Icons.wifi, color: Colors.blue),
          SizedBox(width: 8),
          Text('Выберите Wi-Fi сеть'),
        ],
      ),
      children: [
        _WifiNetworkList(onNetworkSelected: onNetworkSelected),
      ],
    );
  }
}

class _WifiNetworkList extends StatefulWidget {
  final Function(String ssid, String? password) onNetworkSelected;
  
  const _WifiNetworkList({required this.onNetworkSelected});

  @override
  State<_WifiNetworkList> createState() => _WifiNetworkListState();
}

class _WifiNetworkListState extends State<_WifiNetworkList> {
  List<WifiNetworkInfo> _networks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    final networks = await WifiScanHelper.scanNetworks();
    setState(() {
      _networks = networks;
      _isLoading = false;
    });
  }

  void _selectNetwork(WifiNetworkInfo network) {
    if (network.secured) {
      // Показываем диалог ввода пароля
      final passwordController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Пароль для ${network.ssid}'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onNetworkSelected(network.ssid, passwordController.text);
                Navigator.pop(context); // Закрываем основной диалог
              },
              child: const Text('Выбрать'),
            ),
          ],
        ),
      );
    } else {
      widget.onNetworkSelected(network.ssid, null);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_networks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.wifi_off, size: 48),
              SizedBox(height: 16),
              Text('Нет доступных сетей'),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 300,
      height: 400,
      child: ListView.builder(
        itemCount: _networks.length,
        itemBuilder: (context, index) {
          final network = _networks[index];
          return ListTile(
            leading: Icon(
              network.secured ? Icons.lock : Icons.lock_open,
              color: network.secured ? Colors.grey : Colors.green,
            ),
            title: Text(network.ssid),
            subtitle: Text('Сигнал: ${network.signalStrength}%'),
            trailing: Icon(
              Icons.wifi,
              color: _getSignalColor(network.signalStrength),
            ),
            onTap: () => _selectNetwork(network),
          );
        },
      ),
    );
  }

  Color _getSignalColor(int strength) {
    if (strength >= 70) return Colors.green;
    if (strength >= 40) return Colors.orange;
    return Colors.red;
  }
}