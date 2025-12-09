import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sekarang service ini gak connect langsung ke MQTT,
/// tapi ngobrol ke FastAPI di Railway:
/// https://pcb-mqtt-production.up.railway.app
class MqttService {
  // ------------------ KONFIG API (Railway) ------------------
  static const String _baseUrl = 'https://pcb-mqtt-production.up.railway.app';

  // TOPIK STATUS (konsep, biar nama tetap sama di UI)
  static const String topicSuhu        = 'pcb01/status/suhu';
  static const String topicKelembaban  = 'pcb01/status/kelembaban';
  static const String topicLampuStatus = 'pcb01/status/lampu';

  // TOPIK COMMAND (konsep, tapi sekarang lewat HTTP)
  static const String topicCmdLampu       = 'pcb01/cmd/lampu';
  static const String topicCmdPompaMinum  = 'pcb01/cmd/pompa_minum';
  static const String topicCmdPompaSiram  = 'pcb01/cmd/pompa_siram';

  // Stream untuk UI (tetap sama kayak versi MQTT)
  final _suhuController = StreamController<String>.broadcast();
  final _kelembabanController = StreamController<String>.broadcast();
  final _lampuStatusController = StreamController<String>.broadcast();

  Stream<String> get suhuStream => _suhuController.stream;
  Stream<String> get kelembabanStream => _kelembabanController.stream;
  Stream<String> get lampuStatusStream => _lampuStatusController.stream;

  bool _isConnecting = false;
  bool _isConnected = false;

  Timer? _pollTimer; // buat polling /status berkala

  // Constructor lama masih ada biar file lain gak error,
  // tapi parameternya sekarang cuma formalitas.
  MqttService({
    required String broker,
    required int port,
    required String clientId,
  }) {
    print('🐔 [API] Init client (HTTP mode)');
    print('    → baseUrl: $_baseUrl');
  }

  // ------------------ PUBLIC API ------------------

  /// "Connect" sekarang artinya: test call ke /status,
  /// kalau sukses → mulai polling berkala.
  Future<bool> connect() async {
    if (_isConnected) {
      print('ℹ️ [API] connect() dipanggil, tapi sudah connected.');
      return true;
    }
    if (_isConnecting) {
      print('ℹ️ [API] connect() dipanggil, tapi masih proses connecting.');
      return false;
    }

    _isConnecting = true;
    print('🚀 [API] Test koneksi ke $_baseUrl/status ...');

    try {
      final res = await http.get(Uri.parse('$_baseUrl/status'))
          .timeout(const Duration(seconds: 5));

      print('📡 [API] /status → code: ${res.statusCode}');
      if (res.statusCode == 200) {
        _isConnected = true;
        _isConnecting = false;
        print('✅ [API] Backend siap, mulai polling status.');
        _startPollingStatus();
        _handleStatusResponse(res.body); // isi pertama
        return true;
      } else {
        _isConnecting = false;
        _isConnected = false;
        print('❌ [API] Gagal tes /status: ${res.body}');
        return false;
      }
    } catch (e) {
      print('❌ [API] Exception saat connect/test /status: $e');
      _isConnecting = false;
      _isConnected = false;
      return false;
    }
  }

  /// Kirim perintah lampu: 'AUTO', 'ON', 'OFF'
  Future<void> publishLampuCommand(String cmd) async {
    if (!_isConnected) {
      print('⚠️ [API] publishLampuCommand diabaikan, belum connected.');
      return;
    }
    final payload = cmd.toUpperCase();
    print('📤 [API] Lampu CMD → $payload');

    final uri = Uri.parse('$_baseUrl/control/lampu');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mode': payload}),
      );

      print('📡 [API] POST /control/lampu → ${res.statusCode}');
      if (res.statusCode != 200) {
        print('❌ [API] Gagal kirim CMD lampu: ${res.body}');
      }
    } catch (e) {
      print('❌ [API] Exception kirim CMD lampu: $e');
    }
  }

  /// Kirim perintah pompa minum: true = ON, false = OFF
  Future<void> publishPompaMinumCommand(bool on) async {
    if (!_isConnected) {
      print('⚠️ [API] publishPompaMinum diabaikan, belum connected.');
      return;
    }
    final payload = on;
    print('📤 [API] Pompa Minum CMD → ${payload ? 'ON' : 'OFF'}');

    final uri = Uri.parse('$_baseUrl/control/pompa-minum');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'on': payload}),
      );

      print('📡 [API] POST /control/pompa-minum → ${res.statusCode}');
      if (res.statusCode != 200) {
        print('❌ [API] Gagal kirim CMD pompa minum: ${res.body}');
      }
    } catch (e) {
      print('❌ [API] Exception kirim CMD pompa minum: $e');
    }
  }

  /// Kirim perintah pompa siram: true = ON, false = OFF
  Future<void> publishPompaSiramCommand(bool on) async {
    if (!_isConnected) {
      print('⚠️ [API] publishPompaSiram diabaikan, belum connected.');
      return;
    }
    final payload = on;
    print('📤 [API] Pompa Siram CMD → ${payload ? 'ON' : 'OFF'}');

    final uri = Uri.parse('$_baseUrl/control/pompa-siram');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'on': payload}),
      );

      print('📡 [API] POST /control/pompa-siram → ${res.statusCode}');
      if (res.statusCode != 200) {
        print('❌ [API] Gagal kirim CMD pompa siram: ${res.body}');
      }
    } catch (e) {
      print('❌ [API] Exception kirim CMD pompa siram: $e');
    }
  }

  void disconnect() {
    print('🔌 [API] disconnect() dipanggil.');
    _pollTimer?.cancel();
    _pollTimer = null;
    _isConnected = false;
  }

  void dispose() {
    print('🧹 [API] dispose() dipanggil, tutup polling & stream.');
    _pollTimer?.cancel();
    _pollTimer = null;
    _suhuController.close();
    _kelembabanController.close();
    _lampuStatusController.close();
  }

  // ------------------ INTERNAL: POLLING STATUS ------------------

  void _startPollingStatus() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _fetchStatusOnce(),
    );
  }

  Future<void> _fetchStatusOnce() async {
    final uri = Uri.parse('$_baseUrl/status');
    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        _handleStatusResponse(res.body);
      } else {
        print('❌ [API] /status gagal: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      print('❌ [API] Exception GET /status: $e');
    }
  }

  void _handleStatusResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      final suhu = data['suhu']?.toString();
      final kelembaban = data['kelembaban']?.toString();
      final lampuStatus = data['lampu_status']?.toString();

      print('📩 [API] Status diterima: suhu=$suhu, hum=$kelembaban, lampu=$lampuStatus');

      if (suhu != null) {
        _suhuController.add(suhu);
      }
      if (kelembaban != null) {
        _kelembabanController.add(kelembaban);
      }
      if (lampuStatus != null) {
        _lampuStatusController.add(lampuStatus);
      }
    } catch (e) {
      print('❌ [API] Gagal parse body /status: $e');
    }
  }
}
