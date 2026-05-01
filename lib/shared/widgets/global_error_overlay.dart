import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/global_error_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Wraps the app's root child in a [Stack] and renders an animated error toast
/// at the bottom of the screen whenever [GlobalErrorProvider] has an active entry.
///
/// Usage: wrap [child] with this in main.dart's MaterialApp builder.
class GlobalErrorOverlay extends StatelessWidget {
  final Widget child;

  const GlobalErrorOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Consumer<GlobalErrorProvider>(
          builder: (context, errorProvider, _) {
            final entry = errorProvider.current;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 1.2),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  )),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: entry == null
                  ? const SizedBox.shrink()
                  : _ErrorToast(
                      key: ValueKey(entry.timestamp),
                      entry: entry,
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _ErrorToast extends StatelessWidget {
  final GlobalErrorEntry entry;

  const _ErrorToast({super.key, required this.entry});

  Color _accentColor() {
    switch (entry.severity) {
      case ErrorSeverity.error:
        return AppColors.error;
      case ErrorSeverity.warning:
        return AppColors.warning;
      case ErrorSeverity.info:
        return AppColors.secondary;
      case ErrorSeverity.success:
        return AppColors.success;
    }
  }

  Color _bgColor(bool isDark) {
    switch (entry.severity) {
      case ErrorSeverity.error:
        return isDark ? const Color(0xFF4A1010) : const Color(0xFFFFF0F0);
      case ErrorSeverity.warning:
        return isDark ? const Color(0xFF3D2800) : const Color(0xFFFFFAEB);
      case ErrorSeverity.info:
        return isDark ? const Color(0xFF0A2035) : const Color(0xFFEFF6FF);
      case ErrorSeverity.success:
        return isDark ? const Color(0xFF0A2E1A) : const Color(0xFFECFDF5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final errorProvider = context.read<GlobalErrorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final accent = _accentColor();
    final bg = _bgColor(isDark);

    final title = GlobalErrorProvider.titleForEntry(entry, loc);
    final body = GlobalErrorProvider.bodyForEntry(entry, loc);
    final icon = GlobalErrorProvider.iconForEntry(entry);

    return Positioned(
      bottom: MediaQuery.paddingOf(context).bottom + 12,
      left: 12,
      right: 12,
      child: Material(
        elevation: 6,
        shadowColor: accent.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        color: bg,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left:
                  isRtl ? BorderSide.none : BorderSide(color: accent, width: 4),
              right:
                  isRtl ? BorderSide(color: accent, width: 4) : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          height: 1.3,
                        ),
                      ),
                    if (title.isNotEmpty && body.isNotEmpty)
                      const SizedBox(height: 3),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    if (entry.isRetryable && entry.onRetry != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          errorProvider.dismiss();
                          entry.onRetry?.call();
                        },
                        child: Text(
                          loc.errRetry,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => errorProvider.dismiss(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
