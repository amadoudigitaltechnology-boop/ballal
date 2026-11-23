import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'app.dart';
import 'core/config.dart';
import 'core/push.dart';
import 'core/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');

  if (!AppConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  await Session.instance.init();
  await PushService.instance.init();
  runApp(const BallalApp());
}

/// Écran affiché si les variables d'environnement n'ont pas été fournies à la compilation.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configuration manquante.\nLancez avec : flutter run --dart-define-from-file=env/dev.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
