import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';

class LocaleNotifier extends AsyncNotifier<Locale> {
  static const String _localeKey = 'app_locale';
  static const Locale _defaultLocale = Locale('ar', 'IQ');

  @override
  Future<Locale> build() => _loadLocale();

  Future<Locale> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);
      if (localeCode != null) {
        final parts = localeCode.split('_');
        if (parts.length == 2) {
          return Locale(parts[0], parts[1]);
        }
      }
    } catch (e) {
      // Use default locale if loading fails
    }
    return _defaultLocale;
  }

  Future<void> setLocale(Locale locale) async {
    if (!AppLocalizations.supportedLocales.contains(locale)) return;

    // Optimistically update state before saving
    state = AsyncData(locale);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, '${locale.languageCode}_${locale.countryCode}');
    } catch (e) {
      // Ignore save errors
    }
  }

  Future<void> toggleLocale() async {
    final current = state.valueOrNull ?? _defaultLocale;
    final newLocale = current.languageCode == 'ar'
        ? const Locale('en', 'US')
        : const Locale('ar', 'IQ');
    await setLocale(newLocale);
  }
}

final localeProvider =
    AsyncNotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
