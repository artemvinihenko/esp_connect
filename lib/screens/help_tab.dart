import 'package:flutter/material.dart';
import '../widgets/code_viewer.dart';
import '../widgets/info_card.dart';

class HelpTab extends StatefulWidget {
  const HelpTab({super.key});

  @override
  State<HelpTab> createState() => _HelpTabState();
}

class _HelpTabState extends State<HelpTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.blue.shade50,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.wifi_tethering), text: 'SmartConfig'),
              Tab(icon: Icon(Icons.settings_ethernet), text: 'AP режим'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [SmartConfigHelpContent(), APModeHelpContent()],
          ),
        ),
      ],
    );
  }
}

class SmartConfigHelpContent extends StatelessWidget {
  const SmartConfigHelpContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(
            title: 'Что такое SmartConfig?',
            content:
                'SmartConfig - технология от Texas Instruments, которая позволяет передать SSID и пароль Wi-Fi сети на ESP устройство без необходимости подключаться к его точке доступа. Телефон отправляет данные через UDP broadcast, ESP их перехватывает и подключается к Wi-Fi.',
            icon: Icons.info_outline,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          CodeViewer(
            title: 'Код для ESP8266:',
            code: '''
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
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // Ваш код здесь
}''',
          ),
          const SizedBox(height: 16),
          CodeViewer(
            title: 'Код для ESP32:',
            code: '''
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
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // Ваш код здесь
}''',
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'Важно!',
            content:
                '• SmartConfig работает через broadcast и настраивает ВСЕ ESP в режиме SmartConfig в сети\n• Для выбора конкретного устройства используйте AP режим\n• Убедитесь, что телефон подключен к той же Wi-Fi сети\n• Некоторые роутеры блокируют broadcast - используйте AP режим',
            icon: Icons.warning,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }
}

class APModeHelpContent extends StatelessWidget {
  const APModeHelpContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(
            title: 'Что такое AP режим?',
            content:
                'В AP режиме ESP создает собственную Wi-Fi точку доступа. Телефон подключается к этой точке и отправляет настройки через HTTP запросы. Этот метод более надежен и позволяет настраивать конкретное устройство.',
            icon: Icons.info_outline,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          CodeViewer(
            title: 'Код для ESP8266 (AP + HTTP сервер):',
            code: '''
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>

const char* ap_ssid = "ESP_Config";
const char* ap_password = "12345678";

ESP8266WebServer server(80);

void setup() {
  Serial.begin(115200);
  
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_ssid, ap_password);
  
  server.on("/config", HTTP_POST, []() {
    if (server.hasArg("plain")) {
      DynamicJsonDocument doc(256);
      deserializeJson(doc, server.arg("plain"));
      
      String ssid = doc["ssid"];
      String password = doc["password"];
      
      server.send(200, "application/json", "{"status":"ok"}");
      
      WiFi.mode(WIFI_STA);
      WiFi.begin(ssid.c_str(), password.c_str());
      delay(1000);
      ESP.restart();
    }
  });
  
  server.begin();
}

void loop() {
  server.handleClient();
}''',
          ),
          const SizedBox(height: 16),
          CodeViewer(
            title: 'Код для ESP32 (AP + HTTP сервер):',
            code: '''
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>

const char* ap_ssid = "ESP_Config";
const char* ap_password = "12345678";

WebServer server(80);

void setup() {
  Serial.begin(115200);
  
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_ssid, ap_password);
  
  server.on("/config", HTTP_POST, []() {
    if (server.hasArg("plain")) {
      DynamicJsonDocument doc(256);
      deserializeJson(doc, server.arg("plain"));
      
      String ssid = doc["ssid"];
      String password = doc["password"];
      
      server.send(200, "application/json", "{"status":"ok"}");
      
      WiFi.mode(WIFI_STA);
      WiFi.begin(ssid.c_str(), password.c_str());
      delay(1000);
      ESP.restart();
    }
  });
  
  server.begin();
}

void loop() {
  server.handleClient();
}''',
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'Важно!',
            content:
                '• В AP режиме телефон подключается к Wi-Fi сети ESP\n• По умолчанию IP адрес ESP: 192.168.4.1\n• Можно изменить SSID и пароль AP в коде\n• ESP перезагрузится после успешной настройки\n• Установите библиотеку ArduinoJson через менеджер библиотек',
            icon: Icons.warning,
            color: Colors.amber,
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'Необходимые библиотеки',
            content:
                '• ESP8266: ESP8266WiFi, ESP8266WebServer, ArduinoJson\n• ESP32: WiFi, WebServer, ArduinoJson\n• Установите ArduinoJson версии 6.x',
            icon: Icons.library_books,
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}
