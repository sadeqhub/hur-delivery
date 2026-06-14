import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/order_provider.dart';
import 'core/providers/location_provider.dart';
import 'core/providers/wallet_provider.dart';
import 'core/providers/driver_wallet_provider.dart';
import 'core/riverpod/app_providers.dart';
import 'shared/widgets/global_error_overlay.dart';
import 'core/router/app_router.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/flutterfire_notification_service.dart';
// location_service import removed — permission requested lazily on first use
import 'core/services/global_order_notification_service.dart';
// NotificationWatcher removed - database trigger handles FCM notifications now
// import 'core/services/notification_watcher.dart';
import 'shared/widgets/no_internet_screen.dart';
import 'core/services/precache_service.dart';
import 'core/services/performance_optimizer.dart';
import 'core/utils/system_ui.dart';
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Reduce logs and improve cache in release
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
    PaintingBinding.instance.imageCache.maximumSize = 200;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // ~200MB
  }
  if (!kReleaseMode) {
    debugPrint('\n');
    debugPrint('═══════════════════════════════════════');
    debugPrint('🚀 HUR DELIVERY APP STARTING');
    debugPrint('═══════════════════════════════════════\n');
  }

  // Initialize Mapbox only if a token is provided (avoid bundling token in app)
  try {
    if (AppConstants.mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
      if (!kReleaseMode) debugPrint('✅ Mapbox initialized');
    } else {
      if (!kReleaseMode) debugPrint('ℹ️ Mapbox token not set. Skipping Mapbox initialization.');
    }
  } catch (e) {
    if (!kReleaseMode) debugPrint('❌ Mapbox initialization error: $e');
  }

  // Initialize Supabase with persistence
  if (!kReleaseMode) debugPrint('🔧 Initializing Supabase...');
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: null, // Uses default secure storage (SharedPreferences with encryption)
      autoRefreshToken: true, // Automatically refresh tokens when they expire
    ),
  );
  // Note: Session persistence is enabled by default in Supabase Flutter
  if (!kReleaseMode) debugPrint('✅ Supabase initialized with session persistence (auto-refresh enabled)\n');

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize Crashlytics and register global error handlers
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    if (!kReleaseMode) debugPrint('✅ Firebase initialized with proper configuration');
  } catch (e) {
    if (!kReleaseMode) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('⚠️ Check Firebase configuration');
    }
  }

  // Initialize notification service without blocking startup on permission dialogs.
  // Permissions are requested inside but we don't await — dialogs show after first frame.
  FlutterFireNotificationService.initialize().catchError((e) {
    if (!kReleaseMode) debugPrint('❌ FlutterFire notification service error: $e');
    return null;
  });

  if (!kReleaseMode) debugPrint('ℹ️  Using database trigger for FCM notifications (NotificationWatcher disabled)');

  // Location permission is requested lazily when the feature is first used.
  // Awaiting it here blocks main() on the iOS permission dialog.

  // Performance optimizer runs after first frame — avoids blocking startup
  // with a live Supabase latency probe.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PerformanceOptimizer().initialize().catchError((e) {
      if (!kReleaseMode) debugPrint('⚠️ Performance optimizer error: $e');
      return null;
    });
  });

  // Enable Edge-to-Edge mode for modern Android navigation
  SystemUiUtils.enableEdgeToEdge(
    statusBarColor: Colors.transparent,
    navBarColor: Colors.transparent,
  );

  if (!kReleaseMode) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('✅ APP INITIALIZATION COMPLETE');
    debugPrint('═══════════════════════════════════════\n');
  }

  runApp(const ProviderScope(child: HurDeliveryApp()));
}

class HurDeliveryApp extends ConsumerStatefulWidget {
  const HurDeliveryApp({super.key});

  @override
  ConsumerState<HurDeliveryApp> createState() => _HurDeliveryAppState();
}

class _HurDeliveryAppState extends ConsumerState<HurDeliveryApp> {
  @override
  void initState() {
    super.initState();
    // Set up auth listener to start global notifications
    _setupGlobalNotificationListener();
    // Precache core assets after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PrecacheService.preloadCoreAssets(context);

      // Pre-warm the keyboard engine safely.
      // This eliminates the ~200ms lag on the first tap of any input field.
      try {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      } catch (e) {
        debugPrint('ℹ️ Keyboard engine pre-warm skipped: $e');
      }
    });
  }

  void _setupGlobalNotificationListener() {
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        final userId = session.user.id;
        var userRole = session.user.appMetadata['role'] as String?;
        if (userRole == null) {
          try {
            final refreshed = await Supabase.instance.client.auth.refreshSession();
            userRole = refreshed.session?.user.appMetadata['role'] as String?;
          } catch (_) {}
        }

        if (userRole != null && (userRole == 'driver' || userRole == 'merchant')) {
          Logger.d('🔔 Starting global notifications for $userRole: $userId');
          GlobalOrderNotificationService.initialize(
            userId: userId,
            userRole: userRole,
          );
        }
      } else {
        // User logged out, stop service
        GlobalOrderNotificationService.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider).valueOrNull ?? ThemeMode.light;
    final appLocale = ref.watch(localeProvider).valueOrNull ?? const Locale('ar', 'IQ');
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
    final isArabic = appLocale.languageCode == 'ar';
    final authProvider = context.read<AuthProvider>();

    // Wrap with foreground task handler
    return WithForegroundTask(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => WalletProvider()),
          ChangeNotifierProvider(create: (_) => DriverWalletProvider()),
        ],
        child: MaterialApp.router(
          title: AppLocalizations(appLocale).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,

          // Arabic + English localization
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: appLocale,

          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();

            final mq = MediaQuery.of(context);
            final textDirection =
                isArabic ? TextDirection.rtl : TextDirection.ltr;

            // Show no internet screen if offline
            if (!isOnline) {
              return Directionality(
                textDirection: textDirection,
                child: const NoInternetScreen(),
              );
            }

            // Read screen width only — never viewInsets — so keyboard
            // animation frames don't trigger a full tree rebuild.
            final scale = _getTextScaleFactor(mq.size.width);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: Directionality(
                textDirection: textDirection,
                child: GlobalErrorOverlay(
                  child: GestureDetector(
                    // Dismiss the keyboard when the user taps anywhere
                    // outside a focused input field.
                    behavior: HitTestBehavior.translucent,
                    onTap: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: child,
                  ),
                ),
              ),
            );
          },

          routerConfig: AppRouter.createRouter(authProvider),
        ),
      ),
    );
  }
}

// Helper function for global responsive text scaling
double _getTextScaleFactor(double screenWidth) {
  if (screenWidth < 360) {
    return 0.8; // 20% reduction for very small screens
  } else if (screenWidth < 400) {
    return 0.85; // 15% reduction for small screens
  } else if (screenWidth < 600) {
    return 0.9; // 10% reduction for mobile screens
  } else {
    return 1.0; // No scaling for larger screens
  }
}
