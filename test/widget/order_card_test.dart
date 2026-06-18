// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:hur_delivery/core/providers/order_provider.dart';
import 'package:hur_delivery/core/localization/app_localizations.dart';
import 'package:hur_delivery/features/dashboard/widgets/order_card/order_card.dart';
import 'package:hur_delivery/features/dashboard/widgets/order_card/order_card_actions.dart';
import 'package:hur_delivery/shared/models/order_model.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockOrderProvider extends Mock implements OrderProvider {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a minimal [OrderModel] with the required fields set.
OrderModel _order({
  String status = 'pending',
  double deliveryFee = 1500,
  double totalAmount = 8000,
}) {
  return OrderModel(
    id: 'order-test-001',
    merchantId: 'merchant-001',
    customerName: 'أحمد محمد',
    pickupAddress: 'الكرادة، بغداد',
    pickupLatitude: 33.3152,
    pickupLongitude: 44.3661,
    deliveryAddress: 'المنصور، بغداد',
    deliveryLatitude: 33.3221,
    deliveryLongitude: 44.3583,
    status: status,
    deliveryFee: deliveryFee,
    totalAmount: totalAmount,
    createdAt: DateTime(2025, 1, 1, 10, 0),
  );
}

MockOrderProvider _stubOrderProvider() {
  final provider = MockOrderProvider();
  when(() => provider.getLiveAcceptCountdownSeconds(any())).thenReturn(27);
  when(() => provider.getTimeoutRemaining(any())).thenReturn(27);
  when(() => provider.addListener(any())).thenReturn(null);
  when(() => provider.removeListener(any())).thenReturn(null);
  return provider;
}

/// Wrap [child] in the necessary providers + localizations.
Widget _wrap(Widget child, {OrderProvider? orderProvider}) {
  final provider = orderProvider ?? _stubOrderProvider();

  return ChangeNotifierProvider<OrderProvider>.value(
    value: provider,
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
        child: Scaffold(body: child),
      ),
    ),
  );
}

/// Build a [DriverOrderCard] with no-op callbacks.
Widget _card(OrderModel order, {OrderProvider? orderProvider}) {
  return _wrap(
    DriverOrderCard(
      order: order,
      onOpenPickupMaps: () {},
      onOpenDropoffMaps: () {},
      onOpenFullRouteMaps: () {},
      onCallMerchant: () {},
      onCallCustomer: () {},
      onReject: () {},
      onAccept: () {},
      onPickedUp: () {},
      onDeliver: () {},
    ),
    orderProvider: orderProvider,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DriverOrderCard', () {
    // 1. Pending order shows accept bar and reject button.
    testWidgets('pending order: accept bar and reject button are visible',
        (tester) async {
      await tester.pumpWidget(_card(_order(status: 'pending')));
      await tester.pump();

      // The accept bar is an AcceptOrderLongPressBar
      expect(find.byType(AcceptOrderLongPressBar), findsOneWidget);
      // The pending accept row wraps both reject + accept bar
      expect(find.byType(OrderCardPendingAcceptRow), findsOneWidget);
    });

    // 2. Assigned order also shows accept bar and reject button.
    testWidgets('assigned order: accept bar and reject button are visible',
        (tester) async {
      await tester.pumpWidget(_card(_order(status: 'assigned')));
      await tester.pump();

      expect(find.byType(AcceptOrderLongPressBar), findsOneWidget);
      expect(find.byType(OrderCardPendingAcceptRow), findsOneWidget);
    });

    // 3. Accepted order: pickup-received CTA visible; reject button absent.
    testWidgets(
        'accepted order: pickup-received CTA visible, reject button absent',
        (tester) async {
      await tester.pumpWidget(_card(_order(status: 'accepted')));
      await tester.pump();

      // PostAcceptActions widget must be present instead of PendingAcceptRow
      expect(find.byType(OrderCardPostAcceptActions), findsOneWidget);
      expect(find.byType(OrderCardPendingAcceptRow), findsNothing);

      // The pickup-received label should appear somewhere in the tree
      expect(find.text('تم استلام الطلب'), findsOneWidget);
    });

    // 4. on_the_way order: deliver-complete CTA visible.
    testWidgets('on_the_way order: deliver-complete CTA visible',
        (tester) async {
      await tester.pumpWidget(_card(_order(status: 'on_the_way')));
      await tester.pump();

      expect(find.byType(OrderCardPostAcceptActions), findsOneWidget);
      expect(find.text('تم التوصيل'), findsOneWidget);
    });

    // 5. Delivery fee amount renders on screen.
    testWidgets('delivery fee is rendered on screen', (tester) async {
      await tester.pumpWidget(_card(_order(deliveryFee: 1500)));
      await tester.pump();

      // The OrderCardPayment widget renders "1500 د.ع"
      expect(find.textContaining('1500'), findsWidgets);
    });

    // 6. All 5 quick-action buttons are findable.
    testWidgets('5 quick-action buttons are all present', (tester) async {
      await tester.pumpWidget(_card(_order()));
      await tester.pump();

      // store, flag, route, merchant, customer icons
      expect(find.byIcon(Icons.store_outlined), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.alt_route_rounded), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_pin_circle_outlined), findsOneWidget);
    });
  });
}
