import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ======================================
// Warna global (sama seperti sebelumnya)
// ======================================
class AppColors {
  static const background = Color(0xFFCCDAD1); // soft mint (BG app)
  static const primary    = Color(0xFF788585); // icon, accent, border
  static const secondary  = Color(0xFF9CAEA9); // subtitle, label kecil
  static const dark       = Color(0xFF6F6866); // text utama
  static const darker     = Color(0xFF38302E); // elemen gelap (navbar, icon active)
}

// ======================================
// HOME PAGE: STATUS ONLY (NO CONTROL)
// ======================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Endpoint API Railway
  static const String _baseUrl = 'https://pcb-mqtt-production.up.railway.app';

  bool _isLoading = true;
  String? _error;

  double? _suhu;
  double? _kelembaban;
  String? _lampuStatusRaw;
  String? _pompaMinumRaw;   // ← baru
  String? _pompaSiramRaw;   // ← baru
  bool _mqttConnected = false;

  DateTime? _lastUpdated;

  Timer? _pollingTimer;

  // Dummy data tetap
  static const int _jumlahAyam = 120;
  static const int _umurAyamHari = 18;
  static const int _amonia = 12; // ppm dummy
  static const String _ldr = 'Sedang'; // dummy

  @override
  void initState() {
    super.initState();
    _fetchStatus(); // pertama kali
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchStatus();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      setState(() {
        // loading full cuma di awal
        _isLoading = _suhu == null && _kelembaban == null;
        _error = null;
      });

      final uri = Uri.parse('$_baseUrl/status');
      final resp = await http.get(uri).timeout(const Duration(seconds: 7));

      if (resp.statusCode != 200) {
        setState(() {
          _error = 'Gagal mengambil status (HTTP ${resp.statusCode})';
        });
        return;
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;

      final suhuStr      = data['suhu'] as String?;
      final humStr       = data['kelembaban'] as String?;
      final lampu        = data['lampu_status'] as String?;
      final pompaMinum   = data['pompa_minum'] as String?;   // ← baru
      final pompaSiram   = data['pompa_siram'] as String?;   // ← baru
      final mqtt         = data['mqtt_connected'] as bool? ?? false;

      setState(() {
        _suhu          = (suhuStr != null) ? double.tryParse(suhuStr) : null;
        _kelembaban    = (humStr != null) ? double.tryParse(humStr) : null;
        _lampuStatusRaw = lampu;
        _pompaMinumRaw  = pompaMinum;
        _pompaSiramRaw  = pompaSiram;
        _mqttConnected  = mqtt;
        _lastUpdated    = DateTime.now();
        _isLoading      = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error koneksi: $e';
        _isLoading = false;
      });
    }
  }

  // ================== HELPER STATUS LAMPU ==================
  bool get _lampuOn {
    final raw = (_lampuStatusRaw ?? '').toUpperCase();
    if (raw.isEmpty) return false;
    if (raw == 'ON' || raw.endsWith('_ON')) return true;
    return false;
  }

  String get _lampuModeText {
    final raw = (_lampuStatusRaw ?? '').toUpperCase();
    if (raw.startsWith('AUTO')) return 'Auto';
    if (raw.startsWith('MANUAL')) return 'Manual';
    if (raw == 'ON' || raw == 'OFF') return 'Manual';
    return 'Tidak diketahui';
  }

  String get _lampuStatusDisplay {
    if (_lampuStatusRaw == null) return 'Tidak ada data';
    return _lampuStatusRaw!;
  }

  // helper ON/OFF dari raw string pompa
  bool _pompaOn(String? raw) {
    if (raw == null) return false;
    return raw.toUpperCase() == 'ON';
  }

  String _pompaStatusText(String? raw) {
    if (raw == null) return 'Tidak ada data';
    return raw.toUpperCase();
  }

  // Status suhu/kelembaban simple
  String _statusSuhu(double? val) {
    if (val == null) return '-';
    if (val < 28) return 'Sedikit rendah';
    if (val <= 32) return 'Normal';
    return 'Tinggi';
  }

  String _statusKelembapan(double? val) {
    if (val == null) return '-';
    if (val < 60) return 'Kering';
    if (val <= 75) return 'Sedang';
    return 'Lembap';
  }

  String get _lastUpdatedText {
    if (_lastUpdated == null) return 'Belum pernah';
    final t = _lastUpdated!;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchStatus,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====== HEADER ======
              Text(
                'Dashboard Kandang',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ringkasan kondisi PCB01 Chicken Box',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),

              // Keterangan koneksi + last updated
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _mqttConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _mqttConnected
                        ? 'MQTT: Terhubung'
                        : 'MQTT: Putus (pakai data terakhir)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Update: $_lastUpdatedText',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoading && _error == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // ====== JUMLAH & UMUR AYAM ======
              _buildInfoAyamCard(context),
              const SizedBox(height: 18),

              // ====== GRID SENSOR ======
              _buildSensorGrid(context),
              const SizedBox(height: 20),

              // ====== STATUS PERANGKAT ======
              Text(
                'Status Perangkat',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darker,
                ),
              ),
              const SizedBox(height: 10),
              _buildPerangkatCard(context),
              const SizedBox(height: 20),

              // ====== ALERT TERBARU ======
              Text(
                'Alert Terbaru',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darker,
                ),
              ),
              const SizedBox(height: 10),
              _buildAlertCard(context),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ================== WIDGET: INFO AYAM ==================
  Widget _buildInfoAyamCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.dark.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.dark.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dark.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.egg_outlined,
              color: Colors.black,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_jumlahAyam ekor ayam',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darker,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Umur batch: $_umurAyamHari hari',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  // ================== WIDGET: SENSOR GRID ==================
  Widget _buildSensorGrid(BuildContext context) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1,
      children: [
        _SensorCard(
          title: 'Suhu',
          value: _suhu != null ? '${_suhu!.toStringAsFixed(1)}°C' : '--°C',
          status: _statusSuhu(_suhu),
          icon: Icons.thermostat,
        ),
        _SensorCard(
          title: 'Kelembapan',
          value:
          _kelembaban != null ? '${_kelembaban!.toStringAsFixed(1)}%' : '--%',
          status: _statusKelembapan(_kelembaban),
          icon: Icons.water_drop,
        ),
        _SensorCard(
          title: 'Amonia',
          value: '$_amonia ppm',
          status: 'Aman', // dummy
          icon: Icons.air,
        ),
        _SensorCard(
          title: 'Cahaya (LDR)',
          value: _ldr,
          status: 'Stabil', // dummy
          icon: Icons.wb_sunny_outlined,
        ),
      ],
    );
  }

  // ================== WIDGET: PERANGKAT CARD ==================
  Widget _buildPerangkatCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.dark.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.dark.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withOpacity(0.16),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _DeviceStatusItem(
            icon: Icons.wind_power,
            name: 'Kipas',
            mode: 'Auto',
            isOn: true, // masih dummy
          ),
          const Divider(height: 16, color: AppColors.secondary),
          _DeviceStatusItem(
            icon: Icons.lightbulb_outline,
            name: 'Lampu',
            mode: _lampuModeText,
            isOn: _lampuOn,
            extra: _lampuStatusDisplay,
          ),
          const Divider(height: 16, color: AppColors.secondary),
          _DeviceStatusItem(
            icon: Icons.water_drop_outlined,
            name: 'Pompa Minum',
            mode: 'Remote',
            isOn: _pompaOn(_pompaMinumRaw),
            extra: _pompaStatusText(_pompaMinumRaw),
          ),
          const Divider(height: 16, color: AppColors.secondary),
          _DeviceStatusItem(
            icon: Icons.water_outlined,
            name: 'Pompa Siram',
            mode: 'Remote',
            isOn: _pompaOn(_pompaSiramRaw),
            extra: _pompaStatusText(_pompaSiramRaw),
          ),
        ],
      ),
    );
  }

  // ================== WIDGET: ALERT CARD ==================
  Widget _buildAlertCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active,
            color: AppColors.darker,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Semua sistem aman. Belum ada alert kritis di 1 jam terakhir.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.darker,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== WIDGET KECIL: SENSOR CARD ==========
class _SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String status;
  final IconData icon;

  const _SensorCard({
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dark.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.dark.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withOpacity(0.14),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 24,
              color: AppColors.background,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ========== WIDGET KECIL: PERANGKAT ITEM ==========
class _DeviceStatusItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String mode;
  final bool isOn;
  final String? extra;

  const _DeviceStatusItem({
    required this.icon,
    required this.name,
    required this.mode,
    required this.isOn,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = isOn ? 'ON' : 'OFF';
    final statusColor = isOn ? Colors.green : AppColors.secondary;

    return Row(
      children: [
        Icon(icon, color: AppColors.darker),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Mode: $mode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black
                ),
              ),
              if (extra != null)
                Text(
                  'Status: $extra',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
        Text(
          statusText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}
