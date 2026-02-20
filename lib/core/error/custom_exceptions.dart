/// Base exception for all LUMI app errors.
sealed class LumiException implements Exception {
  const LumiException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (cause: $cause)' : ''}';
}

// ── Auth Exceptions ───────────────────────────────────────────────────────────

/// Thrown when Supabase authentication fails (login, signup, OAuth).
final class AuthException extends LumiException {
  const AuthException(super.message, {super.cause});
}

/// Thrown when the current user session is missing or expired.
final class SessionExpiredException extends LumiException {
  const SessionExpiredException()
    : super('Your session has expired. Please sign in again.');
}

// ── Storage / Upload Exceptions ────────────────────────────────────────────────

/// Thrown when uploading an image to Supabase Storage fails.
final class StorageUploadException extends LumiException {
  const StorageUploadException(super.message, {super.cause});
}

/// Thrown when image compression fails before upload.
final class ImageCompressionException extends LumiException {
  const ImageCompressionException(super.message, {super.cause});
}

// ── Database / Network Exceptions ─────────────────────────────────────────────

/// Thrown when a Supabase database query fails.
final class DatabaseException extends LumiException {
  const DatabaseException(super.message, {super.cause});
}

/// Thrown when no network connection is available.
final class NetworkException extends LumiException {
  const NetworkException()
    : super('No internet connection. Please check your network and try again.');
}

// ── Collection / Curation Exceptions ─────────────────────────────────────────

/// Thrown when creating or updating a collection fails.
final class CollectionException extends LumiException {
  const CollectionException(super.message, {super.cause});
}

/// Thrown when a requested collection is not found.
final class CollectionNotFoundException extends LumiException {
  const CollectionNotFoundException(String collectionId)
    : super('Collection not found: $collectionId');
}

// ── Validation Exceptions ─────────────────────────────────────────────────────

/// Thrown when user input or data fails validation.
final class ValidationException extends LumiException {
  const ValidationException(super.message);
}

// ── Unknown / Unexpected ──────────────────────────────────────────────────────

/// Fallback for any unclassified error.
final class UnexpectedException extends LumiException {
  const UnexpectedException({Object? cause})
    : super('An unexpected error occurred. Please try again.', cause: cause);
}

// ── Helper Extension ──────────────────────────────────────────────────────────

extension ExceptionUserMessage on LumiException {
  /// Returns a short, user-friendly message for display in toast/snackbar.
  String get userMessage => message;
}
