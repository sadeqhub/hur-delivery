import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compatibility helper — Riverpod 3 exposes [AsyncValue.value] instead of valueOrNull.
extension AsyncValueOrNull<T> on AsyncValue<T> {
  T? get valueOrNull => value;
}
