/// Pattern for automatically redacting sensitive information from logs.
///
/// Defines a regex pattern to match sensitive data and a replacement string.
/// Multiple built-in patterns are provided for common PII types.
///
/// ## Built-in Patterns
///
/// - [email] - Email addresses
/// - [phone] - International phone numbers
/// - [phoneIndonesia] - Indonesian phone numbers
/// - [creditCard] - Credit card numbers
/// - [ipAddress] - IPv4 and IPv6 addresses
/// - [jwtToken] - JWT tokens
/// - [nopolIndonesia] - Indonesian vehicle plates
///
/// ## Example
///
/// ```dart
/// // Use built-in patterns
/// redactionPatterns: RedactionPattern.defaults
///
/// // Custom pattern
/// RedactionPattern(
///   name: 'api_key',
///   pattern: RegExp(r'api_key[=:]\s*([a-zA-Z0-9]+)'),
///   replacement: 'api_key=[REDACTED]',
/// )
/// ```
class RedactionPattern {
  /// Creates a redaction pattern with the specified name, regex, and replacement.
  ///
  /// - [name]: Identifier for this pattern (for debugging/logging)
  /// - [pattern]: Regex pattern to match sensitive data
  /// - [replacement]: String to replace matched data (default: '[REDACTED]')
  const RedactionPattern({
    required this.name,
    required this.pattern,
    this.replacement = '[REDACTED]',
  });

  /// Name of this pattern (for identification).
  final String name;

  /// Regex pattern to match.
  final RegExp pattern;

  /// Replacement string.
  final String replacement;

  /// Apply redaction to text.
  String apply(String text) {
    return text.replaceAll(pattern, replacement);
  }

  // ==========================================
  // Built-in patterns
  // ==========================================

  /// Email pattern.
  static final email = RedactionPattern(
    name: 'email',
    pattern: RegExp(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'),
    replacement: '[EMAIL_REDACTED]',
  );

  /// Phone number pattern (international).
  static final phone = RedactionPattern(
    name: 'phone',
    pattern: RegExp(
      r'\b(?:\+?\d{1,4}[-.\s]?)?(?:\(\d{1,4}\)[-.\s]?)?\d{1,4}[-.\s]?\d{1,4}[-.\s]?\d{3,9}\b',
    ),
    replacement: '[PHONE_REDACTED]',
  );

  /// Indonesian phone number.
  /// Supports mobile (08xx) and landlines (021, 022, etc) with separators.
  static final phoneIndonesia = RedactionPattern(
    name: 'phone_indonesia',
    pattern: RegExp(r'(?:\+62|62|0)(?:2\d|8\d)[-.\s]?\d{3,4}[-.\s]?\d{3,5}\b'),
    replacement: '[PHONE_REDACTED]',
  );

  /// Credit card pattern.
  /// Supports Visa/Mastercard (16), Amex (15), Diners (14).
  static final creditCard = RedactionPattern(
    name: 'credit_card',
    pattern: RegExp(
      r'\b(?:\d{4}[-\s]?){3}\d{4}\b|\b\d{4}[-\s]?\d{6}[-\s]?\d{5}\b|\b\d{4}[-\s]?\d{6}[-\s]?\d{4}\b',
    ),
    replacement: '[CARD_REDACTED]',
  );

  /// IP address pattern (IPv4 and IPv6).
  static final ipAddress = RedactionPattern(
    name: 'ip_address',
    pattern: RegExp(
      r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b|\b(?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}\b',
      caseSensitive: false,
    ),
    replacement: '[IP_REDACTED]',
  );

  /// JWT token pattern.
  static final jwtToken = RedactionPattern(
    name: 'jwt_token',
    pattern: RegExp(r'eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]*'),
    replacement: '[TOKEN_REDACTED]',
  );

  /// Indonesian vehicle plate number (nopol).
  static final nopolIndonesia = RedactionPattern(
    name: 'nopol_indonesia',
    pattern: RegExp(r'\b[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}\b'),
    replacement: '[NOPOL_REDACTED]',
  );

  /// Get all default patterns.
  static List<RedactionPattern> get defaults => [
        email,
        creditCard,
        phone,
        phoneIndonesia,
        ipAddress,
        jwtToken,
        nopolIndonesia,
      ];
}
