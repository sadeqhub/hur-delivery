/// Canonical order-status enum. Single source of truth for all DB values.
/// Dart exhaustive switches will catch any missing cases at compile time.
enum OrderStatus {
  pending('pending'),
  assigned('assigned'),
  accepted('accepted'),
  onTheWay('on_the_way'),
  pickedUp('picked_up'),
  delivered('delivered'),
  cancelled('cancelled'),

  /// All assigned drivers rejected; merchant can re-broadcast.
  rejected('rejected'),

  /// Returned to unassigned pool after driver rejection cycle.
  unassigned('unassigned'),

  unknown('unknown');

  const OrderStatus(this._db);
  final String _db;

  String toDb() => _db;

  static OrderStatus fromDb(String? v) {
    for (final s in values) {
      if (s._db == v) return s;
    }
    return unknown;
  }

  String get arabicDisplayName => switch (this) {
        pending => 'قيد الانتظار',
        assigned => 'تم التعيين',
        accepted => 'تم القبول',
        onTheWay => 'في الطريق',
        pickedUp => 'تم الاستلام',
        delivered => 'تم التسليم',
        cancelled => 'ملغي',
        rejected => 'مرفوض',
        unassigned => 'غير معيّن',
        unknown => 'غير معروف',
      };

  /// True while the order still needs action (not yet in a terminal state).
  bool get isActive => switch (this) {
        pending => true,
        assigned => true,
        accepted => true,
        onTheWay => true,
        pickedUp => true,
        unassigned => true,
        delivered => false,
        cancelled => false,
        rejected => false,
        unknown => false,
      };

  /// True when the order will never advance further.
  bool get isTerminal =>
      this == delivered || this == cancelled || this == rejected;

  /// True once the driver has physically picked up the package.
  bool get driverHasPickedUp => switch (this) {
        pickedUp => true,
        delivered => true,
        pending => false,
        assigned => false,
        accepted => false,
        onTheWay => false,
        cancelled => false,
        rejected => false,
        unassigned => false,
        unknown => false,
      };

  /// True while the driver is actively moving toward pickup or delivery.
  bool get driverIsMoving => switch (this) {
        onTheWay => true,
        pickedUp => true,
        pending => false,
        assigned => false,
        accepted => false,
        delivered => false,
        cancelled => false,
        rejected => false,
        unassigned => false,
        unknown => false,
      };

  Set<OrderStatus> get allowedTransitions => switch (this) {
        pending => {assigned, cancelled},
        assigned => {accepted, cancelled},
        accepted => {onTheWay, cancelled},
        onTheWay => {pickedUp, cancelled},
        pickedUp => {delivered, cancelled},
        delivered => {},
        cancelled => {},
        rejected => {unassigned, cancelled},
        unassigned => {assigned, cancelled},
        unknown => {},
      };
}
