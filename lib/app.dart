import 'package:flutter/material.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/core/router/app_router.dart';
import 'package:padel_app/core/theme/app_theme.dart';

class PadelApp extends StatefulWidget {
  const PadelApp({super.key});

  @override
  State<PadelApp> createState() => _PadelAppState();
}

class _PadelAppState extends State<PadelApp> {
  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      SupabaseConfig.auth.onAuthStateChange.listen((data) {
        AppRouter.router.refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Padel Stats',
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}
