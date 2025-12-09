import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late MqttServerClient client;

  // MQTT CONFIG (EMQX Cloud)
  static const String _host =
      'wss://k2519aa6.ala.asia-southeast1.emqxsl.com/mqtt';
  static const int _port = 8084;
  static const String _clientId = 'flutter-emqx-dashboard-1';

  // GANTI SESUAI EMQX KAMU (tanpa {})
  static const String _username = 'PCB01';
  static const String _password = '5ywnMzsVX4Ss9vH';

  // TOPIK STATUS (sesuai ESP32)
  static const String topicSuhu = 'pcb01/status/suhu';
  static const String topicKelembaban = 'pcb01/status/kelembaban';
  static const String topicLampuStatus = 'pcb01/status/lampu';
  static const String topicPompaMinumStatus = 'pcb01/status/pompa_minum';
  static const String topicPompaSiramStatus = 'pcb01/status/pompa_siram';
  // OPTIONAL: kalau nanti ESP32 publish LDR, bisa pakai ini
  static const String topicLdrStatus = 'pcb01/status/ldr';

  // TOPIK COMMAND
  static const String topicCmdLampu = 'pcb01/cmd/lampu';
  static const String topicCmdPompaMinum = 'pcb01/cmd/pompa_minum';
  static const String topicCmdPompaSiram = 'pcb01/cmd/pompa_siram';

  // STATE DATA
  String connectionStatus = 'Connecting...';
  double? suhu;
  double? kelembaban;
  String lampuStatus = '-';
  String pompaMinumStatus = '-';
  String pompaSiramStatus = '-';
  String ldrStatus = '-';

  @override
  void initState() {
    super.initState();
    _connectMqtt();
  }

  // ================== MQTT CONNECT ==================
  Future<void> _connectMqtt() async {
    client = MqttServerClient(_host, _clientId);
    client.port = _port;
    client.useWebSocket = true;
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.setProtocolV311();

    client.onConnected = () {
      setState(() {
        connectionStatus = 'Connected';
      });
    };

    client.onDisconnected = () {
      setState(() {
        connectionStatus = 'Disconnected';
      });
    };

    client.onSubscribed = (topic) {
      debugPrint('Subscribed to $topic');
    };

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMess;

    try {
      debugPrint('Connecting to EMQX Cloud...');
      await client.connect(_username, _password);
    } catch (e) {
      debugPrint('MQTT connect error: $e');
      client.disconnect();
      setState(() {
        connectionStatus = 'Error';
      });
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint(
          'EMQX connected: ${client.connectionStatus?.state} (${client.connectionStatus?.returnCode})');
      setState(() {
        connectionStatus = 'Connected';
      });

      // Subscribe semua topik status
      client.subscribe(topicSuhu, MqttQos.atMostOnce);
      client.subscribe(topicKelembaban, MqttQos.atMostOnce);
      client.subscribe(topicLampuStatus, MqttQos.atMostOnce);
      client.subscribe(topicPompaMinumStatus, MqttQos.atMostOnce);
      client.subscribe(topicPompaSiramStatus, MqttQos.atMostOnce);
      client.subscribe(topicLdrStatus, MqttQos.atMostOnce); // kalau ada

      client.updates?.listen(_handleMessage);
    } else {
      debugPrint(
          'EMQX connect failed: ${client.connectionStatus?.state} / ${client.connectionStatus?.returnCode}');
      setState(() {
        connectionStatus = 'Failed';
      });
      client.disconnect();
    }
  }

  // ================== HANDLE MESSAGE ==================
  void _handleMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    final recMess = events[0].payload as MqttPublishMessage;
    final payload =
    MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    final topic = events[0].topic;

    debugPrint('[$topic] => $payload');

    setState(() {
      if (topic == topicSuhu) {
        suhu = double.tryParse(payload);
      } else if (topic == topicKelembaban) {
        kelembaban = double.tryParse(payload);
      } else if (topic == topicLampuStatus) {
        lampuStatus = payload;
      } else if (topic == topicPompaMinumStatus) {
        pompaMinumStatus = payload;
      } else if (topic == topicPompaSiramStatus) {
        pompaSiramStatus = payload;
      } else if (topic == topicLdrStatus) {
        ldrStatus = payload;
      }
    });
  }

  // ================== PUBLISH COMMAND ==================
  void _publishCommand(String topic, String message) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('Cannot publish, MQTT not connected');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint('SEND [$topic] $message');
  }

  // ================== UI WIDGETS ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PCB01 Chicken Box'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 16),
            _buildEnvCard(),
            const SizedBox(height: 16),
            _buildLdrCard(),
            const SizedBox(height: 16),
            _buildLampControlCard(),
            const SizedBox(height: 16),
            _buildPumpControlCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    Color color;
    if (connectionStatus == 'Connected') {
      color = Colors.green;
    } else if (connectionStatus == 'Connecting...') {
      color = Colors.orange;
    } else if (connectionStatus == 'Error' || connectionStatus == 'Failed') {
      color = Colors.red;
    } else {
      color = Colors.grey;
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'MQTT: $connectionStatus',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEnvCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.thermostat, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kondisi Lingkungan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suhu: ${suhu != null ? '${suhu!.toStringAsFixed(1)} °C' : '-'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Kelembaban: ${kelembaban != null ? '${kelembaban!.toStringAsFixed(1)} %' : '-'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLdrCard() {
    // LDR belum dipublish dari ESP32, jadi sementara pakai teks sederhana
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.light_mode, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Cahaya (LDR)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ldrStatus != '-' ? ldrStatus : 'Belum ada data LDR',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLampControlCard() {
    String prettyStatus;
    if (lampuStatus.startsWith('AUTO')) {
      prettyStatus = 'Mode AUTO (${lampuStatus.contains('ON') ? 'ON' : 'OFF'})';
    } else if (lampuStatus.startsWith('MANUAL')) {
      prettyStatus =
      'Mode MANUAL (${lampuStatus.contains('ON') ? 'ON' : 'OFF'})';
    } else {
      prettyStatus = lampuStatus;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lampu Kandang',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Status: $prettyStatus'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _publishCommand(topicCmdLampu, 'AUTO'),
                  icon: const Icon(Icons.settings_suggest),
                  label: const Text('AUTO'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _publishCommand(topicCmdLampu, 'ON'),
                  icon: const Icon(Icons.lightbulb),
                  label: const Text('ON'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _publishCommand(topicCmdLampu, 'OFF'),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('OFF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpControlCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kontrol Pompa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSinglePumpRow(
              title: 'Pompa Minum',
              status: pompaMinumStatus,
              onOn: () => _publishCommand(topicCmdPompaMinum, 'ON'),
              onOff: () => _publishCommand(topicCmdPompaMinum, 'OFF'),
            ),
            const SizedBox(height: 12),
            _buildSinglePumpRow(
              title: 'Pompa Siram',
              status: pompaSiramStatus,
              onOn: () => _publishCommand(topicCmdPompaSiram, 'ON'),
              onOff: () => _publishCommand(topicCmdPompaSiram, 'OFF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePumpRow({
    required String title,
    required String status,
    required VoidCallback onOn,
    required VoidCallback onOff,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text('Status: $status'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onOn,
          child: const Text('ON'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onOff,
          child: const Text('OFF'),
        ),
      ],
    );
  }
}
