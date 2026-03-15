import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:padel_app/app.dart';
import 'package:padel_app/core/network/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await SupabaseConfig.initialize();
  }
  runApp(const ProviderScope(child: PadelApp()));
}
