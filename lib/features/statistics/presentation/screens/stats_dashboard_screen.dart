import 'package:flutter/material.dart';
import 'package:padel_app/l10n/app_localizations.dart';

class StatsDashboardScreen extends StatelessWidget {
  const StatsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statistics),
      ),
      body: const Center(
        child: Text('Stats dashboard — coming in Milestone 1.5'),
      ),
    );
  }
}
