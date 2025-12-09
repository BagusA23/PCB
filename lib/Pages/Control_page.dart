import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pcb/mqtt_service.dart'; // service yg sekarang sudah HTTP ke Railway
import 'home_page.dart'; // buat AppColors

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const String _baseUrl =
      'https://pcb-mqtt-production.up.railway.app'; // sama dgn HomePage

  late MqttService _mqtt;
  bool _isConnecting = true;
  bool _isConnected = false;

  /// Mode yang dipakai UI:
  /// 'AUTO' | 'MANUAL_ON' | 'MANUAL_OFF'
  String _lampuMode = 'AUTO';
  bool _pompaMinumOn = false;
  bool _pompaSiramOn = false;

  bool _isSyncingState = false;

  @override
  void initState() {
    super.initState();

    _mqtt = MqttService(
      broker: 'k2519aa6.ala.asia-southeast1.emqxsl.com',
      port: 8883,
      clientId: 'Mobile-Control-ChickenBox',
    );

    // listen status lampu dari backend (kalau stream ini dipakai)
    _mqtt.lampuStatusStream.listen((status) {
      setState(() {
        final upper = status.toUpperCase();
        if (upper == 'AUTO' || upper.startsWith('AUTO')) {
          _lampuMode = 'AUTO';
        } else if (upper == 'ON' || upper.endsWith('_ON')) {
          _lampuMode = 'MANUAL_ON';
        } else if (upper == 'OFF' || upper.endsWith('_OFF')) {
          _lampuMode = 'MANUAL_OFF';
        }
      });
    });

    _connectBackend();
  }

  Future<void> _connectBackend() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final ok = await _mqtt.connect();
      setState(() {
        _isConnected = ok;
        _isConnecting = false;
      });

      if (ok) {
        // setelah connect, sync state awal dari API
        await _syncStateFromBackend();
      }
    } catch (_) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
    }
  }

  Future<void> _syncStateFromBackend() async {
    if (!mounted) return;
    setState(() {
      _isSyncingState = true;
    });

    try {
      final uri = Uri.parse('$_baseUrl/status');
      final resp = await http.get(uri).timeout(const Duration(seconds: 7));

      if (resp.statusCode != 200) {
        setState(() {
          _isSyncingState = false;
        });
        return;
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;

      final lampuRaw = data['lampu_status'] as String?;
      final pompaMinumRaw = data['pompa_minum'] as String?;
      final pompaSiramRaw = data['pompa_siram'] as String?;

      setState(() {
        // sinkron lampu
        if (lampuRaw != null) {
          final upper = lampuRaw.toUpperCase();
          if (upper.startsWith('AUTO')) {
            _lampuMode = 'AUTO';
          } else if (upper == 'ON' || upper.endsWith('_ON')) {
            _lampuMode = 'MANUAL_ON';
          } else if (upper == 'OFF' || upper.endsWith('_OFF')) {
            _lampuMode = 'MANUAL_OFF';
          }
        }

        // sinkron pompa dari backend (ON/OFF)
        _pompaMinumOn = (pompaMinumRaw ?? 'OFF').toUpperCase() == 'ON';
        _pompaSiramOn = (pompaSiramRaw ?? 'OFF').toUpperCase() == 'ON';

        _isSyncingState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSyncingState = false;
      });
    }
  }

  void _setLampuMode(String cmd) {
    if (!_isConnected) {
      _showNotConnectedSnackBar();
      return;
    }
    _mqtt.publishLampuCommand(cmd);
    // opsional: update local mode biar UI responsif
    setState(() {
      if (cmd == 'AUTO') {
        _lampuMode = 'AUTO';
      } else if (cmd == 'ON') {
        _lampuMode = 'MANUAL_ON';
      } else if (cmd == 'OFF') {
        _lampuMode = 'MANUAL_OFF';
      }
    });
  }

  void _togglePompaMinum(bool value) {
    if (!_isConnected) {
      _showNotConnectedSnackBar();
      // jangan ubah state kalau belum connected
      return;
    }
    setState(() => _pompaMinumOn = value);
    _mqtt.publishPompaMinumCommand(value);
  }

  void _togglePompaSiram(bool value) {
    if (!_isConnected) {
      _showNotConnectedSnackBar();
      return;
    }
    setState(() => _pompaSiramOn = value);
    _mqtt.publishPompaSiramCommand(value);
  }

  void _showNotConnectedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Belum terhubung ke server kontrol. Coba Refresh dulu.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _mqtt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // penting buat AutomaticKeepAliveClientMixin
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== HEADER ==========
            Text(
              'Kontrol Perangkat',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Atur lampu, pompa minum, dan pompa siram kandang.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // ========== STATUS KONEKSI ==========
            _buildConnectionCard(context),
            const SizedBox(height: 20),

            // ========== KONTROL LAMPU ==========
            _buildLampControlCard(context),
            const SizedBox(height: 20),

            // ========== KONTROL POMPA ==========
            _buildPompaControlCard(context),
          ],
        ),
      ),
    );
  }

  // ================== WIDGET: CONNECTION CARD ==================
  Widget _buildConnectionCard(BuildContext context) {
    String text;
    Color dotColor;

    if (_isConnecting) {
      text = 'Menghubungkan ke server kontrol...';
      dotColor = Colors.orange;
    } else if (_isConnected) {
      text = _isSyncingState
          ? 'Terhubung, sinkron status...'
          : 'Terhubung ke server kontrol (API Railway)';
      dotColor = Colors.green;
    } else {
      text = 'Tidak terhubung ke server kontrol';
      dotColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black,
              ),
            ),
          ),
          TextButton(
            onPressed: _isConnecting ? null : () async {
              await _connectBackend();
            },
            child: const Text(
              'Refresh',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // ================== WIDGET: LAMP CONTROL ==================
  Widget _buildLampControlCard(BuildContext context) {
    String readableStatus;
    if (_lampuMode == 'MANUAL_ON') {
      readableStatus = 'Manual ON';
    } else if (_lampuMode == 'MANUAL_OFF') {
      readableStatus = 'Manual OFF';
    } else {
      readableStatus = 'Otomatis';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.background,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lampu Kandang',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'Mode saat ini: $readableStatus',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Pilih mode lampu:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _ModeChip(
                label: 'AUTO',
                selected: _lampuMode == 'AUTO',
                enabled: _isConnected,
                onTap: () => _setLampuMode('AUTO'),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: 'ON',
                selected: _lampuMode == 'MANUAL_ON',
                enabled: _isConnected,
                onTap: () => _setLampuMode('ON'),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: 'OFF',
                selected: _lampuMode == 'MANUAL_OFF',
                enabled: _isConnected,
                onTap: () => _setLampuMode('OFF'),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'AUTO: logika di ESP32 yang atur berdasarkan jam/sensor.\n'
                'ON/OFF: paksa relay sesuai perintah aplikasi.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ================== WIDGET: POMPA CONTROL ==================
  Widget _buildPompaControlCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kontrol Pompa',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Atur pompa minum dan pompa siram dari aplikasi.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            value: _pompaMinumOn,
            activeColor: Colors.green,
            title: const Text(
              'Pompa Minum',
              style: TextStyle(color: Colors.black),
            ),
            subtitle: const Text(
              'Relay untuk air minum ayam',
              style: TextStyle(color: Colors.black),
            ),
            onChanged: _isConnected ? _togglePompaMinum : null,
          ),

          const Divider(),

          SwitchListTile(
            value: _pompaSiramOn,
            activeColor: Colors.green,
            title: const Text(
              'Pompa Siram',
              style: TextStyle(color: Colors.black),
            ),
            subtitle: const Text(
              'Pompa untuk penyemprotan / pendinginan',
              style: TextStyle(color: Colors.black),
            ),
            onChanged: _isConnected ? _togglePompaSiram : null,
          ),
        ],
      ),
    );
  }
}

// ========== MODE CHIP KECIL UNTUK LAMPU ==========
class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.darker,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      onSelected: enabled ? (_) => onTap() : null,
    );
  }
}
