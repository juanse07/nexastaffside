import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../services/api_exception.dart';

/// Maps an error (typically caught from a service call) to a user-friendly
/// localized string.  [ApiException] instances are mapped to specific l10n
/// keys based on status code; everything else falls back to a generic message.
String localizedErrorMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context)!;

  if (error is! ApiException) {
    return l10n.errorSomethingWentWrong;
  }

  if (error.isNetworkError) return l10n.errorNetworkUnavailable;
  if (error.isServerError) return l10n.errorServerUnavailable;
  if (error.isNotAuthenticated) return l10n.errorNotAuthenticated;
  if (error.isConflict) return l10n.errorAppIdInUse;
  if (error.isValidation) return l10n.errorValidationFailed;

  // If the backend sent a human-readable message that doesn't look like a
  // raw exception string, surface it directly.
  final msg = error.message;
  if (msg.isNotEmpty && !msg.startsWith('Exception')) {
    return msg;
  }

  return l10n.errorSomethingWentWrong;
}
