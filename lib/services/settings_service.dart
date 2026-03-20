// Сервис для работы с настройками приложения
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'encryption_service.dart';

class SettingsService {
  // Файл настроек
  static const String _settingsFileName = 'app_settings.json';
  
  // Ключи для хранения
  static const String _apiKeyKey = 'api_key';
  static const String _baseUrlKey = 'base_url';
  static const String _selectedModelKey = 'selected_model';
  static const String _temperatureKey = 'temperature';
  static const String _maxTokensKey = 'max_tokens';
  static const String _deleteApiKeyOnExitKey = 'delete_api_key_on_exit';
  static const String _selectedServiceKey = 'selected_service';
  
  // Значения по умолчанию
  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 1000;
  
  // Список доступных сервисов
  static const List<String> availableServices = [
    'https://openrouter.ai/api/v1',
    'https://api.vsetgpt.ru/v1',
  ];
  
  // Текущие настройки
  String? _apiKey;
  String? _baseUrl;
  String? _selectedModel;
  double _temperature = defaultTemperature;
  int _maxTokens = defaultMaxTokens;
  bool _deleteApiKeyOnExit = false;
  String _selectedService = defaultBaseUrl;
  
  // Геттеры
  String? get apiKey => _apiKey;
  String? get baseUrl => _baseUrl;
  String? get selectedModel => _selectedModel;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;
  bool get deleteApiKeyOnExit => _deleteApiKeyOnExit;
  String get selectedService => _selectedService;
  
  // Сеттер для флага удаления ключа при выходе
  set deleteApiKeyOnExit(bool value) {
    _deleteApiKeyOnExit = value;
    _saveDeleteFlag();
  }
  
  // Сеттер для выбранного сервиса
  set selectedService(String value) {
    _selectedService = value;
    _baseUrl = value;
    _saveSelectedService();
  }
  
  // Флаг инициализации
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // Singleton
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();
  
  // Путь к файлу настроек (кэшируем после первого получения)
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
        // Пытаемся найти папку data рядом с exe, если её нет - используем директорию exe
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
  
  // Путь к файлу настроек
  Future<File> _getSettingsFile() async {
    if (_cachedFilePath != null) {
      return File(_cachedFilePath!);
    }
    
    final directory = await _getAppDirectory();
    final filePath = '${directory.path}/$_settingsFileName';
    _cachedFilePath = filePath;
    debugPrint('Settings file path: $filePath');
    return File(filePath);
  }
  
  // Сохранение только флага удаления API ключа
  Future<void> _saveDeleteFlag() async {
    try {
      final file = await _getSettingsFile();
      Map<String, dynamic> data = {};
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        data = jsonDecode(contents) as Map<String, dynamic>;
      }
      
      data[_deleteApiKeyOnExitKey] = _deleteApiKeyOnExit;
      await file.writeAsString(jsonEncode(data));
      debugPrint('Delete API key flag saved: $_deleteApiKeyOnExit');
    } catch (e) {
      debugPrint('Error saving delete flag: $e');
    }
  }
  
  // Сохранение выбранного сервиса
  Future<void> _saveSelectedService() async {
    try {
      final file = await _getSettingsFile();
      Map<String, dynamic> data = {};
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        data = jsonDecode(contents) as Map<String, dynamic>;
      }
      
      data[_selectedServiceKey] = _selectedService;
      await file.writeAsString(jsonEncode(data));
      debugPrint('Selected service saved: $_selectedService');
    } catch (e) {
      debugPrint('Error saving selected service: $e');
    }
  }
  
  // Инициализация - загрузка настроек
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final file = await _getSettingsFile();
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;
        
        // Загружаем флаг удаления при выходе
        _deleteApiKeyOnExit = data[_deleteApiKeyOnExitKey] as bool? ?? false;
        
        // Загружаем выбранный сервис
        _selectedService = data[_selectedServiceKey] as String? ?? defaultBaseUrl;
        _baseUrl = _selectedService;
        
        // Загружаем API ключ (расшифровываем если зашифрован)
        // Но только если НЕ установлен флаг удаления при выходе
        if (data.containsKey(_apiKeyKey) && data[_apiKeyKey] != null) {
          final storedKey = data[_apiKeyKey] as String;
          if (_deleteApiKeyOnExit) {
            // Если флаг установлен, не загружаем ключ
            _apiKey = null;
            debugPrint('API key not loaded due to delete on exit flag');
          } else {
            if (EncryptionService.isEncrypted(storedKey)) {
              _apiKey = EncryptionService.decrypt(storedKey);
            } else {
              _apiKey = storedKey;
            }
          }
        }
        
        // Загружаем выбранную модель
        _selectedModel = data[_selectedModelKey] as String?;
        
        // Загружаем параметры
        _temperature = (data[_temperatureKey] as num?)?.toDouble() ?? defaultTemperature;
        _maxTokens = (data[_maxTokensKey] as int?) ?? defaultMaxTokens;
        
        debugPrint('Settings loaded from file: baseUrl=$_baseUrl, hasApiKey=${_apiKey != null}, deleteOnExit=$_deleteApiKeyOnExit, selectedService=$_selectedService');
      } else {
        debugPrint('Settings file not found, using defaults');
        _baseUrl = defaultBaseUrl;
        _selectedService = defaultBaseUrl;
      }
      
      _isInitialized = true;
    } catch (e, stackTrace) {
      debugPrint('Error loading settings: $e');
      debugPrint('Stack trace: $stackTrace');
      
      _baseUrl = defaultBaseUrl;
      _selectedService = defaultBaseUrl;
      
      _isInitialized = true;
    }
  }
  
  // Сохранение настроек
  Future<void> saveSettings({
    String? apiKey,
    String? baseUrl,
    String? selectedModel,
    double? temperature,
    int? maxTokens,
  }) async {
    try {
      // Обновляем значения
      if (apiKey != null) _apiKey = apiKey;
      if (baseUrl != null) {
        _baseUrl = baseUrl;
        _selectedService = baseUrl;
      }
      if (selectedModel != null) _selectedModel = selectedModel;
      if (temperature != null) _temperature = temperature;
      if (maxTokens != null) _maxTokens = maxTokens;
      
      final file = await _getSettingsFile();
      
      // Шифруем API ключ перед сохранением (если не установлен флаг удаления)
      String? encryptedApiKey;
      if (_apiKey != null && !_deleteApiKeyOnExit) {
        encryptedApiKey = EncryptionService.encrypt(_apiKey!);
      }
      
      final data = {
        _apiKeyKey: encryptedApiKey,
        _baseUrlKey: _baseUrl,
        _selectedModelKey: _selectedModel,
        _temperatureKey: _temperature,
        _maxTokensKey: _maxTokens,
        _deleteApiKeyOnExitKey: _deleteApiKeyOnExit,
        _selectedServiceKey: _selectedService,
      };
      
      await file.writeAsString(jsonEncode(data));
      debugPrint('Settings saved successfully');
    } catch (e, stackTrace) {
      debugPrint('Error saving settings: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  // Очистка API ключа (при выходе из приложения)
  Future<void> clearApiKey() async {
    try {
      _apiKey = null;
      final file = await _getSettingsFile();
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;
        data[_apiKeyKey] = null;
        await file.writeAsString(jsonEncode(data));
      }
      debugPrint('API key cleared');
    } catch (e) {
      debugPrint('Error clearing API key: $e');
    }
  }
  
  // Проверка наличия API ключа
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  
  // Проверка наличия базового URL
  bool get hasBaseUrl => _baseUrl != null && _baseUrl!.isNotEmpty;
  
  // Очистка настроек
  Future<void> clearSettings() async {
    try {
      _apiKey = null;
      _baseUrl = null;
      _selectedModel = null;
      _temperature = defaultTemperature;
      _maxTokens = defaultMaxTokens;
      _deleteApiKeyOnExit = false;
      _selectedService = defaultBaseUrl;
      
      final file = await _getSettingsFile();
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('Settings cleared');
    } catch (e) {
      debugPrint('Error clearing settings: $e');
    }
  }
  
  // Получение всех настроек как Map (для отладки)
  Map<String, dynamic> getAllSettings() {
    return {
      'hasApiKey': hasApiKey,
      'baseUrl': _baseUrl,
      'selectedModel': _selectedModel,
      'temperature': _temperature,
      'maxTokens': _maxTokens,
      'deleteApiKeyOnExit': _deleteApiKeyOnExit,
      'selectedService': _selectedService,
    };
  }
}
