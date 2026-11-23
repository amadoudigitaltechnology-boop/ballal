import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/push.dart';
import 'core/theme.dart';
import 'core/unread.dart';
import 'l10n/gen/app_localizations.dart';
import 'router.dart';

class BallalApp extends StatefulWidget {
  const BallalApp({super.key});

  @override
  State<BallalApp> createState() => _BallalAppState();
}

class _BallalAppState extends State<BallalApp> with WidgetsBindingObserver {
  final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Unread.instance.start();
    PushService.instance.attachRouter(_router);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Unread.instance.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BALLAL',
      debugShowCheckedModeBanner: false,
      theme: buildBallalTheme(),
      routerConfig: _router,
      scaffoldMessengerKey: PushService.instance.messengerKey,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
