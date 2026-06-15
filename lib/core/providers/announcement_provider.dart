import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/announcement_model.dart';
import '../services/announcement_service.dart';
import '../../shared/widgets/announcement_dialog.dart';
import '../utils/logger.dart';

class AnnouncementState {
  final bool isInitialized;
  final String? userRole;
  final String? userId;
  final List<AnnouncementModel> announcements;

  const AnnouncementState({
    this.isInitialized = false,
    this.userRole,
    this.userId,
    this.announcements = const [],
  });

  AnnouncementState copyWith({
    bool? isInitialized,
    String? userRole,
    String? userId,
    List<AnnouncementModel>? announcements,
  }) {
    return AnnouncementState(
      isInitialized: isInitialized ?? this.isInitialized,
      userRole: userRole ?? this.userRole,
      userId: userId ?? this.userId,
      announcements: announcements ?? this.announcements,
    );
  }
}

class AnnouncementNotifier extends Notifier<AnnouncementState> {
  final AnnouncementService _announcementService = AnnouncementService();

  Timer? _checkTimer;
  final Set<String> _shownAnnouncementIds = {};
  BuildContext? _context;

  @override
  AnnouncementState build() {
    ref.onDispose(() {
      _checkTimer?.cancel();
    });
    return const AnnouncementState();
  }

  /// Initialize the notifier with user info and start checking.
  /// BuildContext is required because announcements are shown as dialogs.
  Future<void> initialize({
    required String userRole,
    required String userId,
    required BuildContext context,
  }) async {
    _context = context;
    state = state.copyWith(
      isInitialized: true,
      userRole: userRole,
      userId: userId,
    );

    Logger.d('AnnouncementNotifier initialized for role: $userRole');

    // Check immediately on initialization
    await checkAndShowAnnouncements();

    // Then check every 5 seconds
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkAndShowAnnouncements();
    });
  }

  /// Check for new announcements and show them as dialogs.
  Future<void> checkAndShowAnnouncements() async {
    final currentRole = state.userRole;
    final currentUserId = state.userId;
    if (currentRole == null || currentUserId == null) return;
    if (_context == null || !_context!.mounted) return;

    try {
      Logger.d('Checking for announcements...');

      final announcements = await _announcementService
          .getUndismissedAnnouncements(currentRole, currentUserId);

      final newAnnouncements = announcements
          .where((a) => !_shownAnnouncementIds.contains(a.id))
          .toList();

      if (newAnnouncements.isEmpty) return;

      Logger.d('Found ${newAnnouncements.length} new announcements to show');

      for (final announcement in newAnnouncements) {
        if (_context == null || !_context!.mounted) break;

        _shownAnnouncementIds.add(announcement.id);

        await showDialog(
          context: _context!,
          barrierDismissible: false,
          builder: (context) => AnnouncementDialog(
            announcement: announcement,
            userId: currentUserId,
            onDismiss: () {
              _shownAnnouncementIds.add(announcement.id);
            },
          ),
        );
      }

      state = state.copyWith(announcements: announcements);
    } catch (e) {
      Logger.d('Error checking announcements: $e');
    }
  }

  /// Stop checking for announcements.
  void stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
    Logger.d('Stopped checking for announcements');
  }

  /// Resume checking for announcements (only if initialized).
  void resumeChecking() {
    if (state.isInitialized && _checkTimer == null) {
      _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        checkAndShowAnnouncements();
      });
      Logger.d('Resumed checking for announcements');
    }
  }
}

final announcementProvider =
    NotifierProvider<AnnouncementNotifier, AnnouncementState>(
  AnnouncementNotifier.new,
);
