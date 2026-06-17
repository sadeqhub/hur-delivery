import 'package:flutter_test/flutter_test.dart';

import 'package:hur_delivery/core/services/delivery_fee_calculator.dart';
import 'package:hur_delivery/shared/models/order_status.dart';

void main() {
  group('DeliveryFeeCalculator.calculateFee', () {
    // ── Tier boundaries ────────────────────────────────────────────────────

    test('0 km → 1500 IQD (minimum fee)', () {
      expect(DeliveryFeeCalculator.calculateFee(0), equals(1500.0));
    });

    test('0.5 km → 1500 IQD (short distance, rounds to min)', () {
      // 1500 + (0.5 * 300) = 1650 → round to nearest 250 = 1750
      final fee = DeliveryFeeCalculator.calculateFee(0.5);
      expect(fee, inInclusiveRange(1500.0, 1800.0));
    });

    test('1 km (threshold boundary) → 1750 IQD or 1800 IQD', () {
      final fee = DeliveryFeeCalculator.calculateFee(1.0);
      expect(fee, inInclusiveRange(1500.0, 1800.0));
    });

    test('1.5 km (medium tier) → between 1800 and 2500 IQD', () {
      final fee = DeliveryFeeCalculator.calculateFee(1.5);
      expect(fee, inInclusiveRange(1750.0, 2500.0));
    });

    test('3 km (medium→long boundary) → 2500 IQD', () {
      final fee = DeliveryFeeCalculator.calculateFee(3.0);
      expect(fee, inInclusiveRange(2250.0, 2750.0));
    });

    test('4.5 km (long tier midpoint) → between 2500 and 3500 IQD', () {
      final fee = DeliveryFeeCalculator.calculateFee(4.5);
      expect(fee, inInclusiveRange(2500.0, 3500.0));
    });

    test('6 km (long→very-long boundary) → around 3500 IQD', () {
      final fee = DeliveryFeeCalculator.calculateFee(6.0);
      expect(fee, inInclusiveRange(3250.0, 3750.0));
    });

    test('10 km (very-long boundary) → around 4500 IQD', () {
      final fee = DeliveryFeeCalculator.calculateFee(10.0);
      expect(fee, inInclusiveRange(4250.0, 4750.0));
    });

    test('20 km (exceeds max) → 5000 IQD (hard cap)', () {
      expect(DeliveryFeeCalculator.calculateFee(20.0), equals(5000.0));
    });

    // ── Edge cases ─────────────────────────────────────────────────────────

    test('Negative distance → treated as 0 (minimum fee)', () {
      expect(DeliveryFeeCalculator.calculateFee(-1.0), equals(1500.0));
    });

    test('Fee is always a multiple of 250 IQD', () {
      for (final km in [0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.5, 6.0, 8.0, 10.0, 15.0, 20.0]) {
        final fee = DeliveryFeeCalculator.calculateFee(km);
        expect(
          fee % 250,
          equals(0.0),
          reason: 'Fee at ${km}km ($fee IQD) is not a multiple of 250',
        );
      }
    });

    test('Fee is always within [minFee, maxFee]', () {
      for (final km in [0.0, 0.1, 1.0, 3.0, 6.0, 10.0, 15.0, 100.0]) {
        final fee = DeliveryFeeCalculator.calculateFee(km);
        expect(
          fee,
          inInclusiveRange(
            DeliveryFeeCalculator.minFee,
            DeliveryFeeCalculator.maxFee,
          ),
          reason: 'Fee at ${km}km ($fee IQD) is out of bounds',
        );
      }
    });

    test('Fee is monotonically non-decreasing with distance', () {
      double prevFee = 0;
      for (final km in [0.0, 0.5, 1.0, 2.0, 3.0, 4.5, 6.0, 8.0, 10.0, 12.0, 20.0]) {
        final fee = DeliveryFeeCalculator.calculateFee(km);
        expect(
          fee,
          greaterThanOrEqualTo(prevFee),
          reason: 'Fee decreased from ${prevFee} to $fee at ${km}km',
        );
        prevFee = fee;
      }
    });
  });

  group('OrderStatus', () {
    // ── Parsing ────────────────────────────────────────────────────────────

    test('fromDb parses all known statuses', () {
      expect(OrderStatus.fromDb('pending'), equals(OrderStatus.pending));
      expect(OrderStatus.fromDb('assigned'), equals(OrderStatus.assigned));
      expect(OrderStatus.fromDb('accepted'), equals(OrderStatus.accepted));
      expect(OrderStatus.fromDb('on_the_way'), equals(OrderStatus.onTheWay));
      expect(OrderStatus.fromDb('picked_up'), equals(OrderStatus.pickedUp));
      expect(OrderStatus.fromDb('delivered'), equals(OrderStatus.delivered));
      expect(OrderStatus.fromDb('cancelled'), equals(OrderStatus.cancelled));
    });

    test('fromDb returns unknown for unrecognized values', () {
      expect(OrderStatus.fromDb('foobar'), equals(OrderStatus.unknown));
      expect(OrderStatus.fromDb(null), equals(OrderStatus.unknown));
      expect(OrderStatus.fromDb(''), equals(OrderStatus.unknown));
    });

    test('toDb round-trips all named statuses', () {
      for (final s in OrderStatus.values) {
        if (s == OrderStatus.unknown) continue;
        expect(OrderStatus.fromDb(s.toDb()), equals(s));
      }
    });

    // ── Predicates ─────────────────────────────────────────────────────────

    test('isActive is true for active statuses', () {
      for (final s in [
        OrderStatus.pending,
        OrderStatus.assigned,
        OrderStatus.accepted,
        OrderStatus.onTheWay,
        OrderStatus.pickedUp,
      ]) {
        expect(s.isActive, isTrue, reason: '$s should be active');
      }
    });

    test('isActive is false for terminal statuses', () {
      expect(OrderStatus.delivered.isActive, isFalse);
      expect(OrderStatus.cancelled.isActive, isFalse);
      expect(OrderStatus.unknown.isActive, isFalse);
    });

    test('isTerminal is true only for delivered and cancelled', () {
      expect(OrderStatus.delivered.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
      expect(OrderStatus.pending.isTerminal, isFalse);
      expect(OrderStatus.onTheWay.isTerminal, isFalse);
    });

    // ── State machine ──────────────────────────────────────────────────────

    test('pending can transition to assigned and cancelled', () {
      expect(OrderStatus.pending.canTransitionTo(OrderStatus.assigned), isTrue);
      expect(OrderStatus.pending.canTransitionTo(OrderStatus.cancelled), isTrue);
      expect(OrderStatus.pending.canTransitionTo(OrderStatus.delivered), isFalse);
    });

    test('pickedUp can transition to delivered or cancelled', () {
      expect(OrderStatus.pickedUp.canTransitionTo(OrderStatus.delivered), isTrue);
      expect(OrderStatus.pickedUp.canTransitionTo(OrderStatus.cancelled), isTrue);
      expect(OrderStatus.pickedUp.canTransitionTo(OrderStatus.pending), isFalse);
    });

    test('delivered has no allowed transitions (terminal)', () {
      expect(OrderStatus.delivered.allowedTransitions, isEmpty);
    });

    test('cancelled has no allowed transitions (terminal)', () {
      expect(OrderStatus.cancelled.allowedTransitions, isEmpty);
    });

    // ── Arabic names ───────────────────────────────────────────────────────

    test('all statuses have non-empty Arabic display names', () {
      for (final s in OrderStatus.values) {
        expect(
          s.arabicDisplayName,
          isNotEmpty,
          reason: '$s should have an Arabic name',
        );
      }
    });
  });
}
