import 'dart:math';
import 'dart:typed_data';

/// Function type for providing encryption keys asynchronously.
///
/// Should return a 32-byte key for AES-256 encryption.
/// Typically retrieves the key from secure storage.
typedef KeyProvider = Future<Uint8List> Function();

/// Configuration for log encryption using AES-256-GCM.
///
/// Provides secure encryption for log files to protect sensitive data.
/// Keys should be stored securely (e.g., in Flutter Secure Storage).
///
/// ## Example
///
/// ```dart
/// // With async key provider (recommended)
/// EncryptionConfig.aes256(
///   keyProvider: () async => await secureStorage.read('log_key'),
/// )
///
/// // Generate a new key
/// final key = EncryptionConfig.generateKey();
/// await secureStorage.write('log_key', key);
///
/// // Disable encryption
/// EncryptionConfig.none()
/// ```
class EncryptionConfig {
  /// Creates a disabled encryption configuration.
  ///
  /// Logs will be stored in plain text without encryption.
  const factory EncryptionConfig.none() = _NoEncryption;

  /// Creates AES-256-GCM encryption configuration with an async key provider.
  ///
  /// The [keyProvider] function should return a 32-byte key.
  /// This is the recommended approach as it allows secure key storage.
  factory EncryptionConfig.aes256({
    required KeyProvider keyProvider,
  }) =>
      EncryptionConfig._(
        enabled: true,
        keyProvider: keyProvider,
      );

  /// Creates AES-256-GCM encryption with a static key.
  ///
  /// **WARNING**: Not recommended for production use as the key is stored
  /// in memory. Use [EncryptionConfig.aes256] with a secure key provider instead.
  ///
  /// The [key] must be exactly 32 bytes for AES-256.
  factory EncryptionConfig.aes256WithKey({
    required Uint8List key,
  }) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 requires a 32-byte key, got ${key.length}');
    }
    // Create defensive copy to prevent external mutation
    return EncryptionConfig._(
      enabled: true,
      staticKey: Uint8List.fromList(key),
    );
  }
  const EncryptionConfig._({
    required this.enabled,
    this.keyProvider,
    this.staticKey,
  });

  /// Whether encryption is enabled.
  final bool enabled;

  /// Async key provider function.
  final KeyProvider? keyProvider;

  /// Static key (not recommended for production).
  final Uint8List? staticKey;

  /// Generate a secure random 32-byte key.
  static Uint8List generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
  }

  /// Get the encryption key.
  Future<Uint8List> getKey() async {
    Uint8List key;
    if (staticKey != null) {
      // Return defensive copy to prevent external mutation
      key = Uint8List.fromList(staticKey!);
    } else if (keyProvider != null) {
      key = await keyProvider!();
    } else {
      throw StateError('No key available');
    }

    // Validate key length for AES-256
    if (key.length != 32) {
      throw StateError(
        'Invalid key length from provider: expected 32 bytes for AES-256, got ${key.length}',
      );
    }

    return key;
  }
}

class _NoEncryption implements EncryptionConfig {
  const _NoEncryption();

  @override
  bool get enabled => false;

  @override
  KeyProvider? get keyProvider => null;

  @override
  Uint8List? get staticKey => null;

  @override
  Future<Uint8List> getKey() => throw StateError('Encryption disabled');
}
