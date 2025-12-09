import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pcb/cubit/bottom_nav_cubit.dart';
import 'package:pcb/Pages/index.dart';


// ================== WARNA PALET ==================
class AppColors {
  static const background = Color(0xFFCCDAD1); // warna soft mint utama (BG app)
  static const primary    = Color(0xFF788585); // icon, accent, border
  static const secondary  = Color(0xFF9CAEA9); // subtitle, label kecil
  static const dark       = Color(0xFF6F6866); // text utama
  static const darker     = Color(0xFF38302E); // elemen gelap (navbar, icon active)
}


void main() {
  runApp(const MyApp());
}

// ================== APP ROOT ==================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCB01 Chicken Box',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          background: AppColors.background,
          surface: AppColors.background,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.darker,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.darker,
          displayColor: AppColors.darker,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: BlocProvider(
        create: (_) => BottomNavigationCubit(),
        child: const MainPage(),
      ),
    );
  }
}

// ================== MAIN PAGE + NAV ==================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final List<Widget> _pageNavigation = const [
    HomePage(),
    ControlPage(),
    HistoryPage(),
    AlertsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BottomNavigationCubit, int>(
      builder: (context, state) {
        return Scaffold(
          extendBody: true, // biar animasi curved keliatan smooth
          body: _buildBody(state),
          bottomNavigationBar: CurvedNavigationBar(
            index: state,
            height: 60,
            backgroundColor: Colors.transparent,
            color: AppColors.darker, // warna bar utama
            buttonBackgroundColor: AppColors.dark, // bubble tengah
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 300),
            items: const [
              Icon(Icons.home, size: 30, color: AppColors.background),
              Icon(Icons.tune, size: 30, color: AppColors.background),
              Icon(Icons.timeline, size: 30, color: AppColors.background),
              Icon(Icons.notifications, size: 30, color: AppColors.background),
              Icon(Icons.person, size: 30, color: AppColors.background),
            ],
            onTap: (index) {
              context.read<BottomNavigationCubit>().changePage(index);
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(int index) {
    // safety kalau nanti jumlah item berubah
    if (index < 0 || index >= _pageNavigation.length) {
      return const SizedBox.shrink();
    }
    return _pageNavigation[index];
  }
}

// ================== DUMMY PAGES ==================

class _BasePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _BasePage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "AppBar" custom
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: AppColors.darker,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darker,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Card dummy konten
            Expanded(
              child: Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.dark.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Halaman $title',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darker,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ini masih dummy UI.\nNanti lo bisa isi dengan konten data IoT / kontrol PCB01 Chicken Box.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== HALAMAN 3: HISTORY =====
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BasePage(
      title: 'History',
      subtitle: 'Grafik dan riwayat sensor kandang',
      icon: Icons.timeline,
    );
  }
}

// ===== HALAMAN 4: ALERTS =====
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BasePage(
      title: 'Alerts',
      subtitle: 'Notifikasi suhu, ammonia, dan error',
      icon: Icons.notifications,
    );
  }
}

// ===== HALAMAN 5: PROFILE =====
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BasePage(
      title: 'Profile',
      subtitle: 'Data peternak & pengaturan aplikasi',
      icon: Icons.person,
    );
  }
}
