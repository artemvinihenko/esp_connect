import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class WifiService {
  static Future<String?> getCurrentSSID() async {
    try {
      final ssid = await WiFiForIoTPlugin.getSSID();
      return ssid?.replaceAll('"', '');
    } catch (e) {
      debugPrint('Error getting SSID: $e');
      return null;
    }
  }

  static Future<void> openWifiSettings() async {
    try {
      if (Platform.isIOS) {
        // Для iOS открываем настройки через URL Scheme
        const url = 'app-settings:';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        } else {
          // Альтернативный способ для iOS
          await launchUrl(Uri.parse('App-prefs:root=WIFI'));
        }
      } else if (Platform.isAndroid) {
        // Для Android используем Intent
        try {
          const AndroidIntent(
            action: 'android.settings.WIFI_SETTINGS',
          ).launch();
        } catch (e) {
          // Если Intent не работает, пробуем другой способ
          await WiFiForIoTPlugin.setEnabled(true);
        }
      }
    } catch (e) {
      debugPrint('Error opening wifi settings: $e');
    }
  }

  static Future<bool> connectToAP(String ssid, String? password) async {
    try {
      await WiFiForIoTPlugin.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: (password == null || password.isEmpty)
            ? NetworkSecurity.NONE
            : NetworkSecurity.WPA,
        withInternet: false,
      ).timeout(const Duration(seconds: 15));

      await Future.delayed(const Duration(milliseconds: 1000));

      return result;
    } catch (e) {
      debugPrint('Error connecting to AP: $e');
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await WiFiForIoTPlugin.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  static Future<bool> isConnected() async {
    try {
      final ssid = await WiFiForIoTPlugin.getSSID();
      return ssid != null && ssid.isNotEmpty && ssid != 'null';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isWifiEnabled() async {
    try {
      return await WiFiForIoTPlugin.isEnabled();
    } catch (e) {
      return false;
    }
  }
}
