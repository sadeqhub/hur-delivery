import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/system_status_service.dart';
import '../utils/logger.dart';

class SystemStatusState {
  final bool isSystemEnabled;
  final bool isChecking;

  const SystemStatusState({
    this.isSystemEnabled = true,
    this.isChecking = false,
  });

  bool get isMaintenanceMode => !isSystemEnabled;

  SystemStatusState copyWith({
    bool? isSystemEnabled,
    bool? isChecking,
  }) {
    return SystemStatusState(
      isSystemEnabled: isSystemEnabled ?? this.isSystemEnabled,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

class SystemStatusNotifier extends Notifier<SystemStatusState> {
  final SystemStatusService _systemStatusService = SystemStatusService();

  @override
  SystemStatusState build() {
    ref.onDispose(() {
      _systemStatusService.dispose();
    });
    return const SystemStatusState();
  }

  /// Initialize and start periodic checking.
  Future<void> initialize() async {
    Logger.d('Initializing SystemStatusNotifier...');

    await checkStatus();

    _systemStatusService.startPeriodicChecking();

    _systemStatusService.onStatusChange((isEnabled) {
      state = state.copyWith(isSystemEnabled: isEnabled);
    });

    Logger.d('SystemStatusNotifier initialized');
  }

  /// Manually check system status.
  Future<void> checkStatus() async {
    state = state.copyWith(isChecking: true);

    try {
      final isEnabled = await _systemStatusService.checkSystemStatus();
      state = state.copyWith(isSystemEnabled: isEnabled, isChecking: false);
    } catch (_) {
      state = state.copyWith(isChecking: false);
    }
  }

  /// Refresh status via the service.
  Future<void> refresh() async {
    await _systemStatusService.refresh();
  }
}

final systemStatusProvider =
    NotifierProvider<SystemStatusNotifier, SystemStatusState>(
  SystemStatusNotifier.new,
);
