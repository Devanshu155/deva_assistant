/// Secure storage service — wraps flutter_secure_storage with AES encryption.
/// Used for the Groq API key and any sensitive user data.
/// Data is stored in the Android Keystore — never leaves the device.
library;

import 'dart:convert' as dart_convert;
import 'dart:math' as dart_math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  // Configure Android-specific encryption options (Keystore-backed AES-256)
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Uses Android Keystore System — hardware-backed on supported devices
    ),
  );

  // ── Groq API Key ──────────────────────────────────────────────────────

  /// Store the user's Groq API key securely in Android Keystore.
  Future<void> saveGroqApiKey(String apiKey) async {
    await _storage.write(key: AppConstants.keyGroqApiKey, value: apiKey);
  }

  /// Read the stored Groq API key. Returns null if not set.
  Future<String?> getGroqApiKey() async {
    return _storage.read(key: AppConstants.keyGroqApiKey);
  }

  /// Check whether a Groq API key has been stored.
  Future<bool> hasGroqApiKey() async {
    final key = await getGroqApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  /// Remove the stored API key (e.g., when user logs out or resets).
  Future<void> deleteGroqApiKey() async {
    await _storage.delete(key: AppConstants.keyGroqApiKey);
  }

  // ── User identity ─────────────────────────────────────────────────────

  Future<void> saveUserName(String name) async {
    await _storage.write(key: AppConstants.keyUserName, value: name);
  }

  Future<String?> getUserName() async {
    return _storage.read(key: AppConstants.keyUserName);
  }

  // ── Onboarding flag ───────────────────────────────────────────────────

  Future<void> markOnboardingComplete() async {
    await _storage.write(key: AppConstants.keyOnboardingDone, value: 'true');
  }

  Future<bool> isOnboardingComplete() async {
    final val = await _storage.read(key: AppConstants.keyOnboardingDone);
    return val == 'true';
  }

  // ── Full reset ────────────────────────────────────────────────────────

  /// Wipe all secure storage — used in Settings > Delete All Data.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ── Database Encryption Key ───────────────────────────────────────────

  /// Get the local database encryption key. Generates a secure one if missing.
  Future<String> getDbEncryptionKey() async {
    String? key = await _storage.read(key: AppConstants.keyDbEncryption);
    if (key == null) {
      // Generate a secure 32-byte key
      final random = dart_math.Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = dart_convert.base64UrlEncode(values);
      await _storage.write(key: AppConstants.keyDbEncryption, value: key);
    }
    return key;
  }
}
