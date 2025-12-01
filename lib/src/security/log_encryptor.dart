import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// AES-256-GCM encryption for logs.
class LogEncryptor {
  LogEncryptor(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError(
        'Key must be 32 bytes for AES-256, got ${key.length}',
      );
    }
    _keyBytes = Uint8List.fromList(key);
    _cipher = GCMBlockCipher(AESEngine());
  }

  late final Uint8List _keyBytes;
  late final GCMBlockCipher _cipher;
  bool _disposed = false;

  static const int _ivLength = 12;
  static const int _tagLength = 16;
  static final Random _secureRandom = Random.secure();

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('LogEncryptor has been disposed and cannot be used');
    }
  }

  /// Encrypt plaintext.
  Uint8List encrypt(String plaintext) {
    _checkDisposed();
    final iv = _generateIv();
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    // Reuse cipher, reinitialize with new IV
    _cipher.init(
      true, // encrypt
      AEADParameters(
        KeyParameter(_keyBytes),
        _tagLength * 8, // tag length in bits
        iv,
        Uint8List.fromList([]), // no AAD
      ),
    );

    final ciphertext = Uint8List(plaintextBytes.length + _tagLength);
    final len = _cipher.processBytes(
      plaintextBytes,
      0,
      plaintextBytes.length,
      ciphertext,
      0,
    );
    _cipher.doFinal(ciphertext, len);

    // Prepend IV to ciphertext
    final result = Uint8List(_ivLength + ciphertext.length);
    result.setRange(0, _ivLength, iv);
    result.setRange(_ivLength, result.length, ciphertext);

    return result;
  }

  /// Decrypt ciphertext.
  String decrypt(Uint8List data) {
    _checkDisposed();
    if (data.length < _ivLength + _tagLength) {
      throw ArgumentError('Invalid encrypted data');
    }

    final iv = data.sublist(0, _ivLength);
    final ciphertext = data.sublist(_ivLength);

    // Reuse cipher, reinitialize with IV from data
    _cipher.init(
      false, // decrypt
      AEADParameters(
        KeyParameter(_keyBytes),
        _tagLength * 8,
        iv,
        Uint8List.fromList([]),
      ),
    );

    final plaintext = Uint8List(ciphertext.length - _tagLength);
    final len = _cipher.processBytes(
      ciphertext,
      0,
      ciphertext.length,
      plaintext,
      0,
    );
    _cipher.doFinal(plaintext, len);

    return utf8.decode(plaintext);
  }

  Uint8List _generateIv() {
    final list = List.generate(_ivLength, (_) => _secureRandom.nextInt(256));
    return Uint8List.fromList(list);
  }

  /// Dispose and zero out key bytes from memory.
  void dispose() {
    if (_disposed) return; // Already disposed
    _keyBytes.fillRange(0, _keyBytes.length, 0);
    _disposed = true;
  }
}
