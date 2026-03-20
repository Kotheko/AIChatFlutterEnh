// Сервис для сохранения и загрузки данных приложения
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Класс сервиса для работы с данными приложения
class DataService {
  // Файл данных
  static const String _dataFileName = 'app_data.json';
  
  // Singleton
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();
  
  // Путь к файлу данных (кэшируем после первого получения)
  String? _cachedFilePath;
  
  // Получение директории для сохранения в зависимости от платформы
  Future<Directory> _getAppDirectory() async {
    if (Platform.isAndroid) {
      // Android: используем getApplicationDocumentsDirectory()
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: используем директорию рядом с исполняемым файлом
      if (Platform.isWindows) {
        final exePath = Platform.resolvedExecutable;
        final exeDir = Directory(exePath).parent;
        // Пытаемся найти папку data рядом с exe, если её нет - создаём
        final dataDir = Directory('${exeDir.path}\\data');
        if (await dataDir.exists()) {
          return dataDir;
        }
        return exeDir;
      } else {
        // Для Linux/MacOS - используем директорию рядом с исполняемым файлом
        final exePath = Platform.resolvedExecutable;
        final exeDir = Directory(exePath).parent;
        return exeDir;
      }
    } else {
      // По умолчанию используем ApplicationDocumentsDirectory
      return await getApplicationDocumentsDirectory();
    }
  }
  
  // Получение пути к файлу данных
  Future<File> _getDataFile() async {
    if (_cachedFilePath != null) {
      return File(_cachedFilePath!);
    }
    
    final directory = await _getAppDirectory();
    final filePath = '${directory.path}/$_dataFileName';
    _cachedFilePath = filePath;
    debugPrint('Data file path: $filePath');
    return File(filePath);
  }
  
  // Получение пути для отображения пользователю
  Future<String> getDataFilePath() async {
    final file = await _getDataFile();
    return file.path;
  }
  
  // Сохранение всех данных приложения
  Future<bool> saveAllData({
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> statistics,
    required Map<String, dynamic> expenses,
    String? selectedModel,
  }) async {
    try {
      final file = await _getDataFile();
      
      final data = {
        'version': 1,
        'saved_at': DateTime.now().toIso8601String(),
        'messages': messages,
        'statistics': statistics,
        'expenses': expenses,
        'selected_model': selectedModel,
      };
      
      await file.writeAsString(jsonEncode(data), flush: true);
      debugPrint('All data saved successfully to: ${file.path}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error saving all data: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }
  
  // Загрузка всех данных приложения
  Future<Map<String, dynamic>?> loadAllData() async {
    try {
      final file = await _getDataFile();
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;
        debugPrint('All data loaded successfully from: ${file.path}');
        return data;
      } else {
        debugPrint('Data file does not exist: ${file.path}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading all data: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
  
  // Сохранение сообщений чата
  Future<bool> saveMessages(List<Map<String, dynamic>> messages) async {
    try {
      final allData = await loadAllData() ?? {};
      allData['messages'] = messages;
      allData['messages_saved_at'] = DateTime.now().toIso8601String();
      
      final file = await _getDataFile();
      await file.writeAsString(jsonEncode(allData), flush: true);
      return true;
    } catch (e) {
      debugPrint('Error saving messages: $e');
      return false;
    }
  }
  
  // Загрузка сообщений чата
  Future<List<Map<String, dynamic>>> loadMessages() async {
    try {
      final allData = await loadAllData();
      if (allData != null && allData.containsKey('messages')) {
        return List<Map<String, dynamic>>.from(allData['messages'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return [];
    }
  }
  
  // Сохранение статистики
  Future<bool> saveStatistics(Map<String, dynamic> statistics) async {
    try {
      final allData = await loadAllData() ?? {};
      allData['statistics'] = statistics;
      allData['statistics_saved_at'] = DateTime.now().toIso8601String();
      
      final file = await _getDataFile();
      await file.writeAsString(jsonEncode(allData), flush: true);
      return true;
    } catch (e) {
      debugPrint('Error saving statistics: $e');
      return false;
    }
  }
  
  // Загрузка статистики
  Future<Map<String, dynamic>?> loadStatistics() async {
    try {
      final allData = await loadAllData();
      if (allData != null && allData.containsKey('statistics')) {
        return Map<String, dynamic>.from(allData['statistics'] ?? {});
      }
      return null;
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      return null;
    }
  }
  
  // Сохранение расходов
  Future<bool> saveExpenses(Map<String, dynamic> expenses) async {
    try {
      final allData = await loadAllData() ?? {};
      allData['expenses'] = expenses;
      allData['expenses_saved_at'] = DateTime.now().toIso8601String();
      
      final file = await _getDataFile();
      await file.writeAsString(jsonEncode(allData), flush: true);
      return true;
    } catch (e) {
      debugPrint('Error saving expenses: $e');
      return false;
    }
  }
  
  // Загрузка расходов
  Future<Map<String, dynamic>?> loadExpenses() async {
    try {
      final allData = await loadAllData();
      if (allData != null && allData.containsKey('expenses')) {
        return Map<String, dynamic>.from(allData['expenses'] ?? {});
      }
      return null;
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      return null;
    }
  }
  
  // Сохранение выбранной модели
  Future<bool> saveSelectedModel(String? modelId) async {
    try {
      final allData = await loadAllData() ?? {};
      allData['selected_model'] = modelId;
      
      final file = await _getDataFile();
      await file.writeAsString(jsonEncode(allData), flush: true);
      return true;
    } catch (e) {
      debugPrint('Error saving selected model: $e');
      return false;
    }
  }
  
  // Загрузка выбранной модели
  Future<String?> loadSelectedModel() async {
    try {
      final allData = await loadAllData();
      if (allData != null && allData.containsKey('selected_model')) {
        return allData['selected_model'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading selected model: $e');
      return null;
    }
  }
  
  // Проверка наличия сохраненных данных
  Future<bool> hasSavedData() async {
    try {
      final file = await _getDataFile();
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
  
  // Удаление всех данных
  Future<bool> clearAllData() async {
    try {
      final file = await _getDataFile();
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      debugPrint('Error clearing all data: $e');
      return false;
    }
  }
}
