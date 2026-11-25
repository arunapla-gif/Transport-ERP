import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TransportErpApp());
}

class TransportErpApp extends StatelessWidget {
  const TransportErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arunachalam Transport ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Swiss Transport Blue
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF64748B), // Slate Gray
          tertiary: const Color(0xFF10B981), // Semantic Green
          surface: const Color(0xFFFFFFFF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Soft gray canvas
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0, // Flat Swiss look
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Sharper professional corners
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1), // Crisp 1px border
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: AuthService.initSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withAlpha(15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 48),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 24, 
                      height: 24, 
                      child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2)
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SWISS LOGISTICS ERP',
                      style: TextStyle(
                        color: Color(0xFF0F172A), 
                        fontSize: 16, 
                        fontWeight: FontWeight.w700, 
                        letterSpacing: 1.2
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Initializing secure session...',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.data == true) {
            return const DashboardScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
