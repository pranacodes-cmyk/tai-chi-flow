import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/content.dart';
import 'router.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/tracking_service.dart';
import 'state/app_state.dart';
import 'theme/text.dart';
import 'theme/tokens.dart';
import 'widgets/privacy_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Content.load();
  await PurchaseService.init();
  final app = await AppState.load();
  Haptics.enabled = app.audio.haptics;
  unawaited(TrackingService.init(app));
  unawaited(
    PurchaseService.syncEntitlement(
      isActive: () => app.premium.active,
      grant: app.setPremium,
      revoke: app.cancelPremium,
    ),
  );
  runApp(
    ChangeNotifierProvider.value(
      value: app,
      child: EnsoApp(app: app),
    ),
  );
  _bootstrapReminders(app);
}

Future<void> _bootstrapReminders(AppState app) async {
  await NotificationService.init();
  if (app.onboarded && app.reminders.enabled) {
    await NotificationService.schedule(
      app.reminders,
      name: app.profile.name,
      minutes: app.profile.dailyMinutes,
    );
  }
}

class EnsoApp extends StatefulWidget {
  const EnsoApp({super.key, required this.app});
  final AppState app;
  @override
  State<EnsoApp> createState() => _EnsoAppState();
}

class _EnsoAppState extends State<EnsoApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(widget.app);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.app.addListener(_syncHaptics);
    unawaited(
      PrivacyPrompts.runOnLaunch(
        () => _router.routerDelegate.navigatorKey.currentContext,
      ),
    );
  }

  void _syncHaptics() => Haptics.enabled = widget.app.audio.haptics;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.app.flush();
    }
    if (state == AppLifecycleState.resumed) unawaited(TrackingService.resumed());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.app.removeListener(_syncHaptics);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TaiChi Flow',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: T.family,
        scaffoldBackgroundColor: C.cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: C.jade,
          primary: C.jade,
          surface: C.cream,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: C.jade,
          selectionColor: C.jadeSoft,
          selectionHandleColor: C.jade,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: C.jade,
          inactiveTrackColor: C.sand,
          thumbColor: C.ivory,
          overlayColor: C.jade.withValues(alpha: 0.12),
          trackHeight: 6,
        ),
      ),
      // System font size is honoured up to 130% so large-text users get bigger type
      // without fixed-size cards and buttons breaking apart.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
          child: _Splash(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// In-app splash (web `Splash`): logo spins in, then fades away.
class _Splash extends StatefulWidget {
  const _Splash({required this.child});
  final Widget child;
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () async {
      if (!mounted) return;
      await _out.forward();
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (!_gone)
          AnimatedBuilder(
            animation: Listenable.merge([_in, _out]),
            builder: (_, _) {
              final a = kEase.transform(_in.value);
              final o = kEase.transform(_out.value);
              return IgnorePointer(
                ignoring: _out.value > 0.5,
                child: Opacity(
                  opacity: 1 - o,
                  child: Transform.scale(
                    scale: 1 + 0.04 * o,
                    child: Container(
                      color: C.cream,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: a,
                            child: Transform.rotate(
                              angle: -0.7 * (1 - a),
                              child: Transform.scale(
                                scale: 0.7 + 0.3 * a,
                                child: Image.asset(
                                  'assets/images/logo-taichi.png',
                                  width: 96,
                                  height: 96,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Opacity(
                            opacity: ((_in.value - 0.28) / 0.6).clamp(0.0, 1.0),
                            child: Text(
                              'TaiChi Flow',
                              style: T.displayMd.copyWith(
                                letterSpacing: -0.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Opacity(
                            opacity: ((_in.value - 0.5) / 0.5).clamp(0.0, 1.0),
                            child: Text(
                              'meditation in motion',
                              style: T.serifAccent.copyWith(
                                fontSize: 18.4,
                                color: C.muted,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
