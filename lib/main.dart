import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/tenant_list_screen.dart';

void main() {
  // Initialize FFI for Desktop Support (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(
          surface: Colors.white, // Background of cards
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const TenantListScreen(),
    ),
  );
}
