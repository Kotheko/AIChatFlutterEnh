// Сервис для шифрования и дешифрования данных
import 'dart:convert';
import 'package:flutter/foundation.dart';

class EncryptionService {
  // Простой ключ шифрования (в реальном приложении лучше использовать более сложный)
  // Для Flutter Desktop это можно хранить в защищенном хранилище или получать при первом запуске
  static const String _defaultKey = 'AIChatFlutterEnh_2024_SecureKey';
  
  // Метод для генерации ключа на основе строки
  static Uint8List _generateKey(String seed) {
    final keyBytes = utf8.encode(seed);
    final hash = <int>[];
    
    for (int i = 0; i < 32; i++) {
      hash.add(keyBytes[i % keyBytes.length] ^ (i * 17 + 31));
    }
    
    return Uint8List.fromList(hash);
  }

  // XOR шифрование (простое, но эффективное для базовых задач)
  static String encrypt(String plainText, {String? customKey}) {
    try {
      final key = customKey ?? _defaultKey;
      final keyBytes = _generateKey(key);
      final plainBytes = utf8.encode(plainText);
      final encryptedBytes = <int>[];
      
      for (int i = 0; i < plainBytes.length; i++) {
        encryptedBytes.add(plainBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      // Добавляем marker в начало для идентификации зашифрованных данных
      final marker = [0x41, 0x49, 0x43, 0x45]; // "AICE"
      return base64Encode(Uint8List.fromList([...marker, ...encryptedBytes]));
    } catch (e) {
      debugPrint('Encryption error: $e');
      return plainText;
    }
  }

  // Метод дешифрования
  static String decrypt(String encryptedText, {String? customKey}) {
    try {
      final key = customKey ?? _defaultKey;
      final decodedBytes = base64Decode(encryptedText);
      
      // Проверяем маркер
      if (decodedBytes.length < 4 ||
          decodedBytes[0] != 0x41 ||
          decodedBytes[1] != 0x49 ||
          decodedBytes[2] != 0x43 ||
          decodedBytes[3] != 0x45) {
        // Не зашифрованные данные, возвращаем как есть
        return encryptedText;
      }
      
      final keyBytes = _generateKey(key);
      final encryptedData = decodedBytes.sublist(4);
      final decryptedBytes = <int>[];
      
      for (int i = 0; i < encryptedData.length; i++) {
        decryptedBytes.add(encryptedData[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return utf8.decode(Uint8List.fromList(decryptedBytes));
    } catch (e) {
      debugPrint('Decryption error: $e');
      // Если не удалось расшифровать, возвращаем оригинальный текст
      return encryptedText;
    }
  }

  // Проверка, является ли строка зашифрованной
  static bool isEncrypted(String text) {
    try {
      final decoded = base64Decode(text);
      return decoded.length >= 4 &&
             decoded[0] == 0x41 &&
             decoded[1] == 0x49 &&
             decoded[2] == 0x43 &&
             decoded[3] == 0x45;
    } catch (e) {
      return false;
    }
  }
}
