import 'dart:math';
import 'dart:typed_data';

/// Key provider function type.
typedef KeyProvider = Future<Uint8List> Function();

/// Configuration for log encryption.
class EncryptionConfig {
  /// Create disabled encryption config.
  const factory EncryptionConfig.none() = _NoEncryption;

  /// Create AES-256-GCM encryption with key provider.
  factory EncryptionConfig.aes256({
    required KeyProvider keyProvider,
  }) =>
      EncryptionConfig._(
        enabled: true,
        keyProvider: keyProvider,
      );

  /// Create AES-256-GCM encryption with static key.
  /// WARNING: Not recommended for production.
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
