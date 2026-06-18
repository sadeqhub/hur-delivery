import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  RealtimeChannel? _announcementsChannel;
  final Set<String> _shownAnnouncementIds = {};
  BuildContext? _context;

  @override
  AnnouncementState build() {
    ref.onDispose(() {
      _announcementsChannel?.unsubscribe();
      _announcementsChannel = null;
    });
    return const AnnouncementState();
  }

  /// Initialize the notifier with user info and start listening for changes.
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

    await _subscribeRealtime();
  }

  /// Subscribe to realtime changes on the announcements table.
  /// Performs an immediate initial fetch so the list is populated without
  /// waiting for the first change event.
  Future<void> _subscribeRealtime() async {
    // Immediately populate on startup — don't wait for a change event.
    await checkAndShowAnnouncements();

    _announcementsChannel?.unsubscribe();
    _announcementsChannel = Supabase.instance.client
        .channel('announcements-provider')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'system_announcements',
          callback: (payload) => _onInsertOrUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'system_announcements',
          callback: (payload) => _onInsertOrUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'system_announcements',
          callback: (payload) =>
              _onDelete(payload.oldRecord['id'] as String?),
        )
        .subscribe();

    Logger.d('AnnouncementNotifier: realtime channel subscribed');
  }

  /// Handle INSERT or UPDATE: re-fetch so dismissal filtering, role
  /// filtering, and active-window checks are all applied correctly.
  void _onInsertOrUpdate(Map<String, dynamic> record) {
    Logger.d(
        'AnnouncementNotifier: received INSERT/UPDATE for id=${record['id']}');
    checkAndShowAnnouncements();
  }

  /// Handle DELETE: remove the matching announcement from the local list
  /// immediately without a round-trip.
  void _onDelete(String? id) {
    if (id == null) return;
    Logger.d('AnnouncementNotifier: received DELETE for id=$id');
    final updated = state.announcements.where((a) => a.id != id).toList();
    state = state.copyWith(announcements: updated);
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

      if (newAnnouncements.isEmpty) {
        state = state.copyWith(announcements: announcements);
        return;
      }

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

  /// Pause the realtime subscription (e.g. user logs out or app backgrounds).
  void stopChecking() {
    _announcementsChannel?.unsubscribe();
    _announcementsChannel = null;
    Logger.d('Stopped listening for announcements');
  }

  /// Resume the realtime subscription (only if already initialized).
  void resumeChecking() {
    if (state.isInitialized && _announcementsChannel == null) {
      _subscribeRealtime();
      Logger.d('Resumed listening for announcements');
    }
  }
}

final announcementProvider =
    NotifierProvider<AnnouncementNotifier, AnnouncementState>(
  AnnouncementNotifier.new,
);
