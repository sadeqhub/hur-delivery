# L10N Remaining Files

This document lists files that still contain Arabic string literals that need to be
extracted to AppLocalizations keys.

The auth_provider.dart and key UI strings have been swept in the initial pass.

## Files requiring attention

The following files contain Arabic strings that were NOT swept in the initial pass.
Run `grep -rn "'[أ-ي]" lib/ --include="*.dart" | grep -v "localization\|_localizedValues\|l10n"` to find current count.

Priority groupings:

### High Priority (user-facing error messages)
- lib/shared/widgets/verification_guard.dart — inline Arabic strings in widget
- lib/features/orders/screens/ — order status strings
- lib/features/driver/screens/ — driver flow strings

### Medium Priority
- lib/features/dashboard/ — dashboard labels
- lib/features/wallet/ — wallet descriptions
- lib/features/messaging/ — messaging UI

### Low Priority (admin / internal)
- lib/features/auth/screens/ — additional auth flow strings
- lib/core/services/ — service log messages

## Progress

- [x] lib/core/providers/auth_provider.dart — error codes extracted
- [ ] ~60 remaining files (run the grep above for exact count)

## How to contribute

1. Pick a file from the list above
2. For each Arabic string, add a key to AppLocalizations._localizedValues for 'ar' and 'en'
3. Add the corresponding getter to AppLocalizations
4. Replace the string literal with `AppLocalizations.of(context).yourNewKey`
5. Remove the file from this list
