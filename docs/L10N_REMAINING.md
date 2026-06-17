# L10N Remaining — Hardcoded Arabic Strings

Generated 2026-06-17 after the l10n sweep that moved **23+ keys** out of
`session_service.dart`, `otp_service.dart`, and `auth_provider.dart` into the
hand-written `AppLocalizations` static map.

The grep pattern used: `'[^']*[؀-ۿ][^']*'` (Arabic Unicode block in
single-quoted Dart string literals).  Counts below are *line matches*, not
unique strings.  Files inside `lib/core/localization/` are excluded.

---

## High Priority (100+ matches)

| File | Arabic string line matches |
|------|-------------------------:|
| `lib/features/dashboard/screens/driver_dashboard.dart` | 271 |

## Medium Priority (20–99 matches)

| File | Arabic string line matches |
|------|-------------------------:|
| `lib/core/providers/auth_provider.dart` | 199 |
| `lib/core/services/flutterfire_notification_service.dart` | 125 |
| `lib/core/providers/order_provider.dart` | 119 |
| `lib/features/dashboard/widgets/state_of_the_art_navigation.dart` | 80 |
| `lib/features/dashboard/screens/merchant_dashboard.dart` | 70 |
| `lib/core/data/neighborhoods_data.dart` | 70 |
| `lib/features/auth/screens/user_registration_screen.dart` | 49 |
| `lib/core/services/fcm_service.dart` | 48 |
| `lib/core/services/event_notification_service.dart` | 47 |
| `lib/core/providers/wallet_provider.dart` | 47 |
| `lib/core/services/foreground_service.dart` | 45 |
| `lib/core/services/notification_manager.dart` | 43 |
| `lib/features/orders/screens/create_order_screen.dart` | 42 |
| `lib/core/services/global_order_notification_service.dart` | 40 |
| `lib/core/services/geocoding_service.dart` | 39 |
| `lib/core/services/error_manager.dart` | 35 |
| `lib/features/dashboard/widgets/merchant_stats_banner.dart` | 34 |
| `lib/core/services/driver_location_service.dart` | 32 |
| `lib/features/dashboard/widgets/state_of_the_art_map_widget.dart` | 29 |
| `lib/core/services/persistent_notification_service.dart` | 29 |
| `lib/core/providers/driver_wallet_provider.dart` | 29 |
| `lib/core/services/background_service.dart` | 28 |
| `lib/features/dashboard/screens/admin_dashboard.dart` | 25 |
| `lib/features/auth/screens/id_verification_review_screen.dart` | 22 |
| `lib/core/services/simple_persistent_service.dart` | 22 |
| `lib/features/orders/screens/create_voice_order_screen.dart` | 21 |
| `lib/main.dart` | 20 |

## Lower Priority (1–19 matches)

| File | Arabic string line matches |
|------|-------------------------:|
| `lib/core/services/order_redirect_service.dart` | 19 |
| `lib/features/orders/screens/customer_location_test_screen.dart` | 17 |
| `lib/features/driver/widgets/simple_location_update_widget.dart` | 17 |
| `lib/core/services/version_check_service.dart` | 17 |
| `lib/features/driver/screens/earnings_screen.dart` | 15 |
| `lib/core/services/session_service.dart` | 15 |
| `lib/features/driver/screens/wallet_screen.dart` | 14 |
| `lib/features/dashboard/widgets/merchant_map_widget.dart` | 14 |
| `lib/features/auth/screens/responsive_example_screen.dart` | 12 |
| `lib/features/auth/screens/otp_verification_screen.dart` | 12 |
| `lib/features/dashboard/widgets/merchant_order_list.dart` | 11 |
| `lib/core/services/notification_watcher.dart` | 11 |
| `lib/core/providers/location_provider.dart` | 11 |
| `lib/shared/models/order_status.dart` | 10 |
| `lib/features/auth/screens/verification_pending_screen.dart` | 10 |
| `lib/core/services/whatsapp_service.dart` | 10 |
| `lib/core/services/otp_service.dart` | 10 |
| `lib/shared/widgets/verification_guard.dart` | 9 |
| `lib/shared/models/order_model.dart` | 9 |
| `lib/features/orders/widgets/customer_location_sharing_widget.dart` | 9 |
| `lib/core/services/announcement_service.dart` | 9 |
| `lib/shared/widgets/no_internet_screen.dart` | 8 |
| `lib/shared/widgets/announcement_dialog.dart` | 8 |
| `lib/features/orders/screens/order_details_screen.dart` | 8 |
| `lib/core/services/whatsapp_location_service.dart` | 8 |
| `lib/core/services/messaging_service.dart` | 8 |
| `lib/features/driver/screens/rank_screen.dart` | 7 |
| `lib/shared/models/announcement_model.dart` | 6 |
| `lib/features/orders/widgets/merchant_order_card.dart` | 6 |
| `lib/core/services/request_priority_manager.dart` | 6 |
| `lib/core/services/device_session_service.dart` | 6 |
| `lib/core/services/audio_notification_service.dart` | 6 |
| `lib/core/logging/logger.dart` | 6 |
| `lib/shared/models/scheduled_order_model.dart` | 5 |
| `lib/features/orders/widgets/merchant_bulk_order_card.dart` | 5 |
| `lib/features/orders/screens/create_scheduled_order_screen.dart` | 5 |
| `lib/core/services/route_time_service.dart` | 5 |
| `lib/core/services/optimized_order_loader.dart` | 5 |
| `lib/shared/widgets/neighborhood_dropdown.dart` | 4 |
| `lib/shared/models/voice_recording_model.dart` | 4 |
| `lib/core/services/system_status_service.dart` | 4 |
| `lib/core/services/location_service.dart` | 4 |
| `lib/core/services/delivery_fee_calculator.dart` | 4 |
| `lib/features/orders/widgets/voice_recording_card.dart` | 3 |
| `lib/features/orders/widgets/order_card.dart` | 3 |
| `lib/features/dashboard/widgets/order_card/order_card_ready.dart` | 3 |
| `lib/core/services/screen_visibility_tracker.dart` | 3 |
| `lib/core/services/network_quality_service.dart` | 3 |
| `lib/core/services/mutation_queue_service.dart` | 3 |
| `lib/core/services/driver_availability_service.dart` | 3 |
| `lib/core/router/app_router.dart` | 3 |
| `lib/shared/widgets/empty_state.dart` | 2 |
| `lib/features/wallet/widgets/payment_webview_dialog.dart` | 2 |
| `lib/features/orders/screens/order_tracking_screen.dart` | 2 |
| `lib/features/messaging/screens/support_conversation_screen.dart` | 2 |
| `lib/features/messaging/screens/messaging_thread_screen.dart` | 2 |
| `lib/features/messaging/screens/messaging_list_screen.dart` | 2 |
| `lib/features/dashboard/widgets/driver_map_section.dart` | 2 |
| `lib/core/services/system_settings_service.dart` | 2 |
| `lib/core/services/performance_optimizer.dart` | 2 |
| `lib/core/services/order_provider_optimization_example.dart` | 2 |
| `lib/core/services/najaf_districts_service.dart` | 2 |
| `lib/core/providers/notification_provider.dart` | 2 |
| `lib/core/constants/app_constants.dart` | 2 |
| `lib/shared/widgets/language_switcher.dart` | 1 |
| `lib/shared/widgets/delivery_timer_widget.dart` | 1 |
| `lib/shared/widgets/connectivity_banner.dart` | 1 |
| `lib/features/wallet/widgets/credit_limit_guard.dart` | 1 |
| `lib/features/orders/screens/voice_library_screen.dart` | 1 |
| `lib/features/orders/data/order_repository.dart` | 1 |
| `lib/features/merchant/screens/settings_screen.dart` | 1 |
| `lib/features/driver/screens/settings_screen.dart` | 1 |
| `lib/features/dashboard/widgets/order_card/order_card_actions.dart` | 1 |
| `lib/features/dashboard/widgets/driver_timer_banner.dart` | 1 |
| `lib/core/widgets/header_notification.dart` | 1 |
| `lib/core/services/image_cache_service.dart` | 1 |
| `lib/core/errors/error_mapper.dart` | 1 |

---

## Notes

- **`lib/core/data/neighborhoods_data.dart`** — Contains city/neighbourhood
  name data (proper nouns). These should become a locale-keyed data table,
  not ARB strings.
- **`lib/core/logging/logger.dart`** and service files — Many matches are
  `Logger.d('...')` debug messages. Log messages do not need l10n.
- **`lib/shared/models/*.dart`** — Arabic strings in models are mostly
  `OrderStatus` display labels; move to a locale-aware extension method.
- **`lib/core/services/session_service.dart`** and **`otp_service.dart`** —
  Already swept in this commit; remaining matches are in comment lines or
  debug log calls, not user-visible UI strings.
- **Notification services** (`fcm_service.dart`, `foreground_service.dart`,
  `flutterfire_notification_service.dart`, `notification_manager.dart`,
  `event_notification_service.dart`, `global_order_notification_service.dart`,
  `persistent_notification_service.dart`) — Push notification body strings
  shown in the OS tray must be built server-side or pre-resolved before the
  FCM payload is built. These require a server-side l10n strategy, not just
  client ARB keys.
- **`lib/core/providers/auth_provider.dart`** — 11 error strings were swept
  in this commit; remaining 199 matches include comment text, internal labels,
  and log strings — not user-visible UI copy.
- **Total files affected**: 105 (excluding `app_localizations.dart`)

## Progress

- [x] `lib/core/providers/auth_provider.dart` — 11 user-visible error strings extracted
- [x] `lib/core/services/session_service.dart` — 4 error strings extracted
- [x] `lib/core/services/otp_service.dart` — 10 error strings extracted
- [ ] ~105 remaining files require audit (see tables above)

## How to contribute

1. Pick a file from the tables above.
2. For each Arabic string, add keys to `AppLocalizations._localizedValues`
   for both `'ar'` and `'en'`.
3. Add the corresponding getter to `AppLocalizations`.
4. Replace the string literal with `AppLocalizations.of(context).yourNewKey`.
5. Remove the file from this document.
