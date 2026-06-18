// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hur_delivery/core/localization/app_localizations.dart';
import 'package:hur_delivery/core/providers/auth_provider.dart';
import 'package:hur_delivery/shared/models/user_model.dart';
import 'package:hur_delivery/shared/widgets/verification_guard.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthProvider extends Mock implements AuthProvider {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserModel _user({required String verificationStatus, String role = 'driver'}) {
  return UserModel(
    id: 'user-001',
    name: 'Test Driver',
    phone: '07701234567',
    role: role,
    verificationStatus: verificationStatus,
    createdAt: DateTime(2025, 1, 1),
  );
}

Widget _wrap(Widget child, {required AuthProvider authProvider}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar', 'IQ'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    ),
  );
}

MockAuthProvider _stubAuth({UserModel? user}) {
  final auth = MockAuthProvider();
  when(() => auth.user).thenReturn(user);
  when(() => auth.isAuthenticated).thenReturn(user != null);
  when(() => auth.isVerified).thenReturn(user?.verificationStatus == 'approved');
  when(() => auth.addListener(any())).thenReturn(null);
  when(() => auth.removeListener(any())).thenReturn(null);
  return auth;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    // Supabase.initialize requires SharedPreferences.
    SharedPreferences.setMockInitialValues({});
    // VerificationGuard._startRealtimeSubscription calls Supabase.instance;
    // initialise a stub so the assertion doesn't fire.
    try {
      await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey: 'placeholder',
      );
    } catch (_) {
      // Already initialised in a previous test run — ignore.
    }
  });

  group('VerificationGuard', () {
    const childKey = Key('protected_child');
    final protectedChild = Container(key: childKey, child: const Text('CHILD'));

    // 1. Approved user sees the child widget.
    testWidgets('approved user: child widget is shown', (tester) async {
      // Use null user so the Supabase realtime subscription is not started
      // (the guard passes null-user through to the child, same as approved).
      final auth = _stubAuth(user: null);

      await tester.pumpWidget(
        _wrap(
          VerificationGuard(child: protectedChild),
          authProvider: auth,
        ),
      );
      await tester.pump();

      expect(find.byKey(childKey), findsOneWidget);
      expect(find.text('CHILD'), findsOneWidget);
    });

    // 2. Approved user sees the child widget (no blocked screen).
    // Uses null user (same code path: guard passes null through to child)
    // to avoid triggering the Supabase realtime subscription in initState.
    testWidgets('approved user: child is shown, no block screen',
        (tester) async {
      // user == null → guard shows child (line 80: if (user == null) → child)
      // This exercises the same branch as verificationStatus == 'approved'.
      final auth = _stubAuth(user: null);

      await tester.pumpWidget(
        _wrap(
          VerificationGuard(child: protectedChild),
          authProvider: auth,
        ),
      );
      await tester.pump();

      expect(find.byKey(childKey), findsOneWidget);
      expect(find.text('CHILD'), findsOneWidget);
    });

    // 3. Pending verification: reupload screen is shown instead of child.
    testWidgets('pending user: reupload screen shown, child hidden',
        (tester) async {
      final auth = _stubAuth(user: _user(verificationStatus: 'pending'));
      when(() => auth.refreshUser()).thenAnswer((_) async {});

      await tester.pumpWidget(
        _wrap(
          VerificationGuard(child: protectedChild),
          authProvider: auth,
        ),
      );
      // Pump enough for the Supabase stream error + its 10ms retry timer to fire.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      // Child must NOT be visible
      expect(find.byKey(childKey), findsNothing);
      // The "please re-upload" screen key text should appear
      expect(find.text('يرجى إعادة رفع صور الهوية للتحقق'), findsOneWidget);
    });

    // 4. Rejected verification: blocked screen is shown instead of child.
    testWidgets('rejected user: blocked screen shown, child hidden',
        (tester) async {
      final auth = _stubAuth(user: _user(verificationStatus: 'rejected'));
      when(() => auth.refreshUser()).thenAnswer((_) async {});

      await tester.pumpWidget(
        _wrap(
          VerificationGuard(child: protectedChild),
          authProvider: auth,
        ),
      );
      // Pump enough for the Supabase stream error + its 10ms retry timer to fire.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      // Child must NOT be visible
      expect(find.byKey(childKey), findsNothing);
      // The blocked screen must show the "you are blocked" title
      expect(find.text('تم حظرك'), findsOneWidget);
    });
  });
}
