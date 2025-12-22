import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/tenant_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const ResidenciaApp());
}

class ResidenciaApp extends StatelessWidget {
  const ResidenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Residencia Manager',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const TenantListScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
      ).copyWith(surface: Colors.white),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
