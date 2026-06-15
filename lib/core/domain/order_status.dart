enum OrderStatus {
  pending,
  assigned,
  accepted,
  onTheWay,
  delivered,
  cancelled,
  unassigned,
  rejected,
  unknown;

  /// Returns the snake_case database string for this status.
  String get dbValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.assigned:
        return 'assigned';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.onTheWay:
        return 'on_the_way';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.unassigned:
        return 'unassigned';
      case OrderStatus.rejected:
        return 'rejected';
      case OrderStatus.unknown:
        return 'unknown';
    }
  }

  /// Maps a database string to the corresponding [OrderStatus].
  /// Returns [OrderStatus.unknown] for unrecognized strings.
  static OrderStatus fromDb(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'assigned':
        return OrderStatus.assigned;
      case 'accepted':
        return OrderStatus.accepted;
      case 'on_the_way':
        return OrderStatus.onTheWay;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'unassigned':
        return OrderStatus.unassigned;
      case 'rejected':
        return OrderStatus.rejected;
      default:
        return OrderStatus.unknown;
    }
  }

  /// Returns the set of valid next states from this status.
  Set<OrderStatus> get legalTransitions {
    switch (this) {
      case OrderStatus.pending:
        return {OrderStatus.assigned, OrderStatus.cancelled};
      case OrderStatus.assigned:
        return {
          OrderStatus.accepted,
          OrderStatus.rejected,
          OrderStatus.unassigned,
          OrderStatus.cancelled,
        };
      case OrderStatus.accepted:
        return {OrderStatus.onTheWay, OrderStatus.cancelled};
      case OrderStatus.onTheWay:
        return {OrderStatus.delivered};
      case OrderStatus.delivered:
        return {};
      case OrderStatus.cancelled:
        return {};
      case OrderStatus.unassigned:
        return {OrderStatus.assigned, OrderStatus.cancelled};
      case OrderStatus.rejected:
        return {};
      case OrderStatus.unknown:
        return {};
    }
  }

  /// Whether this status represents an active (non-terminal, non-unknown) order.
  bool get isActive => !isTerminal && this != OrderStatus.unknown;

  /// Whether this status is a terminal state (no further transitions).
  bool get isTerminal =>
      this == OrderStatus.delivered ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.rejected;
}
