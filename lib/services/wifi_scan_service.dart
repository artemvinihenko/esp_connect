import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';

class WifiScanHelper {
  static Future<List<WifiNetworkInfo>> scanNetworks() async {
    try {
      await WiFiForIoTPlugin.setEnabled(true);

      final networks = await WiFiForIoTPlugin.loadWifiList();

      if (networks.isNotEmpty) {
        return networks.map((network) {
          final isSecured =
              network.capabilities?.contains("WPA") == true ||
              network.capabilities?.contains("WEP") == true;

          return WifiNetworkInfo(
            ssid: network.ssid ?? 'Unknown',
            bssid: network.bssid,
            level: network.level ?? -100,
            secured: isSecured,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error scanning networks: $e');
      return [];
    }
  }

  static Future<bool> connectToNetwork(String ssid, String? password) async {
    try {
      return await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: (password == null || password.isEmpty)
            ? NetworkSecurity.NONE
            : NetworkSecurity.WPA,
        withInternet: false,
      );
    } catch (e) {
      debugPrint('Error connecting to network: $e');
      return false;
    }
  }

  static Future<void> disconnect() async {
    await WiFiForIoTPlugin.disconnect();
  }

  static Future<String?> getCurrentSSID() async {
    try {
      final ssid = await WiFiForIoTPlugin.getSSID();
      return ssid?.replaceAll('"', '');
    } catch (e) {
      return null;
    }
  }
}

class WifiNetworkInfo {
  final String ssid;
  final String? bssid;
  final int level;
  final bool secured;

  WifiNetworkInfo({
    required this.ssid,
    this.bssid,
    required this.level,
    required this.secured,
  });

  int get signalStrength {
    final rssi = level.clamp(-100, -50);
    return ((rssi + 100) / 50 * 100).toInt();
  }

  IconData get signalIcon {
    return Icons.wifi;
  }
}
