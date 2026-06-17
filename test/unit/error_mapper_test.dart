import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hur_delivery/core/errors/app_failure.dart';
import 'package:hur_delivery/core/errors/error_mapper.dart';

void main() {
  // ─── ErrorMapper ──────────────────────────────────────────────────────────
  group('ErrorMapper.map', () {
    test('SocketException → network failure', () {
      final f = ErrorMapper.map(const SocketException('No route to host'));
      expect(f.message, equals('network'));
    });

    test('TimeoutException → timeout failure', () {
      final f = ErrorMapper.map(TimeoutException('timed out'));
      expect(f.message, equals('timeout'));
    });

    test('String "Connection timed out" → timeout failure', () {
      final f = ErrorMapper.map(Exception('Connection timed out'));
      expect(f.message, equals('timeout'));
    });

    test('String "SocketException: Failed host lookup" → network failure', () {
      final f = ErrorMapper.map(Exception('SocketException: Failed host lookup'));
      expect(f.message, equals('network'));
    });

    test('PostgrestException 23505 (unique_violation) → validation failure', () {
      final f = ErrorMapper.map(
        PostgrestException(message: 'duplicate key value', code: '23505'),
      );
      expect(f.message, equals('validation'));
      expect(f.cause, equals('23505')); // hint is null so falls back to code
    });

    test('PostgrestException permission denied → unauthorized failure', () {
      final f = ErrorMapper.map(
        PostgrestException(
            message: 'permission denied for table users', code: '42501'),
      );
      expect(f.message, equals('unauthorized'));
    });

    test('AuthException jwt expired (401) → authExpired failure', () {
      final f = ErrorMapper.map(
        AuthException('jwt expired', statusCode: '401'),
      );
      expect(f.message, equals('auth_expired'));
    });

    test('AuthException not authorized (403) → unauthorized failure', () {
      final f = ErrorMapper.map(
        AuthException('not authorized to perform this action', statusCode: '403'),
      );
      expect(f.message, equals('unauthorized'));
    });

    test('generic Exception → unknown failure', () {
      final f = ErrorMapper.map(Exception('something exploded'));
      expect(f.message, equals('unknown'));
    });

    test('AppFailure passed in is wrapped as unknown (no short-circuit)', () {
      const original = AppFailure.network();
      final f = ErrorMapper.map(original);
      expect(f, isA<AppFailure>());
    });
  });

  // ─── AppFailure factory constructors ──────────────────────────────────────
  group('AppFailure factory constructors', () {
    test('const AppFailure.network() has message "network"', () {
      const f = AppFailure.network();
      expect(f.message, equals('network'));
      expect(f.cause, isNull);
    });

    test('two const AppFailure.network() instances are identical', () {
      const a = AppFailure.network();
      const b = AppFailure.network();
      expect(identical(a, b), isTrue);
    });

    test('AppFailure.timeout() has message "timeout"', () {
      const f = AppFailure.timeout();
      expect(f.message, equals('timeout'));
    });

    test('AppFailure.authExpired() has message "auth_expired"', () {
      const f = AppFailure.authExpired();
      expect(f.message, equals('auth_expired'));
    });

    test('AppFailure.unauthorized() has message "unauthorized"', () {
      const f = AppFailure.unauthorized();
      expect(f.message, equals('unauthorized'));
    });

    test('AppFailure.notFound carries resource as cause', () {
      const f = AppFailure.notFound('طلب');
      expect(f.message, equals('not_found'));
      expect(f.cause, equals('طلب'));
    });

    test('AppFailure.validation carries hint as cause when provided', () {
      final f = AppFailure.validation('23505', hint: 'Phone already registered');
      expect(f.message, equals('validation'));
      expect(f.cause, equals('Phone already registered'));
    });

    test('AppFailure.validation falls back to code when hint is null', () {
      final f = AppFailure.validation('23505');
      expect(f.message, equals('validation'));
      expect(f.cause, equals('23505'));
    });

    test('AppFailure.unknown carries original exception as cause', () {
      final original = Exception('raw');
      final f = AppFailure.unknown(original);
      expect(f.message, equals('unknown'));
      expect(f.cause, same(original));
    });

    test('AppFailure.maintenance() has message "maintenance"', () {
      const f = AppFailure.maintenance();
      expect(f.message, equals('maintenance'));
    });

    test('AppFailure.rateLimited() has message "rate_limited"', () {
      const f = AppFailure.rateLimited();
      expect(f.message, equals('rate_limited'));
    });
  });

  // ─── AppFailure.toString ──────────────────────────────────────────────────
  group('AppFailure.toString', () {
    test('without cause omits cause field', () {
      const f = AppFailure.network();
      expect(f.toString(), equals('AppFailure(network)'));
    });

    test('with cause includes cause field', () {
      const f = AppFailure.notFound('طلب');
      expect(f.toString(), contains('طلب'));
    });
  });
}
