import 'package:flutter/material.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';

/// Error state for the qada screens when their data fails to load or the
/// load times out. Previously the screens showed only a spinner in that
/// case, so a stalled load looked like a frozen app with no way forward.
class QadaLoadErrorCard extends StatelessWidget {
  /// Localised message explaining the failure.
  final String message;

  /// Starts a fresh load attempt.
  final VoidCallback onRetry;

  const QadaLoadErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.qadaRetry),
            ),
          ],
        ),
      ),
    );
  }
}
