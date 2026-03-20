// Import JSON library
import 'dart:convert';
// Import HTTP client
import 'package:http/http.dart' as http;
// Import Flutter core classes
import 'package:flutter/foundation.dart';
// Import settings service
import '../services/settings_service.dart';

// Класс клиента для работы с API OpenRouter
class OpenRouterClient {
  // API ключ для авторизации
  String? apiKey;
  // Базовый URL API
  String? baseUrl;
  // Заголовки HTTP запросов
  Map<String, String> headers;

  // Единственный экземпляр класса (Singleton)
  static final OpenRouterClient _instance = OpenRouterClient._internal();

  // Фабричный метод для получения экземпляра
  factory OpenRouterClient() {
    return _instance;
  }

  // Приватный конструктор для реализации Singleton
  OpenRouterClient._internal()
      : headers = {
          'Content-Type': 'application/json', // Указание типа контента
          'X-Title': 'AI Chat Flutter', // Название приложения
        } {
    // Инициализация клиента - будет вызвана позже после загрузки настроек
  }

  // Метод обновления настроек клиента из SettingsService
  void updateFromSettings() {
    try {
      final settings = SettingsService();
      
      apiKey = settings.apiKey;
      baseUrl = settings.baseUrl;
      
      // Обновляем заголовки с новым API ключом
      headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'X-Title': 'AI Chat Flutter',
      };

      if (kDebugMode) {
        print('OpenRouterClient updated from settings');
        print('Base URL: $baseUrl');
        print('Has API Key: ${apiKey != null && apiKey!.isNotEmpty}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error updating OpenRouterClient from settings: $e');
        print('Stack trace: $stackTrace');
      }
    }
  }

  // Метод проверки готовности клиента
  bool get isReady => 
      apiKey != null && apiKey!.isNotEmpty && 
      baseUrl != null && baseUrl!.isNotEmpty;

  // Метод получения списка доступных моделей
  Future<List<Map<String, dynamic>>> getModels() async {
    // Проверяем готовность клиента
    if (!isReady) {
      if (kDebugMode) {
        print('OpenRouterClient not ready, attempting to load from settings...');
      }
      updateFromSettings();
      
      if (!isReady) {
        if (kDebugMode) {
          print('OpenRouterClient still not ready after settings update');
        }
        // Возвращаем пустой список
        return [];
      }
    }

    try {
      // Выполнение GET запроса для получения моделей
      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: headers,
      );

      if (kDebugMode) {
        print('Models response status: ${response.statusCode}');
        print('Models response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        // Парсинг данных о моделях
        final modelsData = json.decode(response.body);
        if (modelsData['data'] != null) {
          return (modelsData['data'] as List)
              .map((model) => {
                    'id': model['id'] as String,
                    'name': (() {
                      try {
                        return utf8.decode((model['name'] as String).codeUnits);
                      } catch (e) {
                        // Remove invalid UTF-8 characters and try again
                        final cleaned = (model['name'] as String)
                            .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
                        return utf8.decode(cleaned.codeUnits);
                      }
                    })(),
                    'pricing': {
                      'prompt': model['pricing']['prompt'] as String,
                      'completion': model['pricing']['completion'] as String,
                    },
                    'context_length': (model['context_length'] ??
                            model['top_provider']['context_length'] ??
                            0)
                        .toString(),
                  })
              .toList();
        }
        throw Exception('Invalid API response format');
      } else {
        // Возвращение пустого списка при ошибке
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting models: $e');
      }
      return [];
    }
  }

  // Метод отправки сообщения через API
  Future<Map<String, dynamic>> sendMessage(String message, String model) async {
    // Проверяем готовность клиента
    if (!isReady) {
      if (kDebugMode) {
        print('OpenRouterClient not ready for sending message');
      }
      updateFromSettings();
      
      if (!isReady) {
        return {'error': 'API не настроен. Пожалуйста, настройте подключение в разделе "Настройки".'};
      }
    }

    final settings = SettingsService();

    try {
      // Подготовка данных для отправки
      final data = {
        'model': model, // Модель для генерации ответа
        'messages': [
          {'role': 'user', 'content': message} // Сообщение пользователя
        ],
        'max_tokens': settings.maxTokens,
        'temperature': settings.temperature,
        'stream': false, // Отключение потоковой передачи
      };

      if (kDebugMode) {
        print('Sending message to API: ${json.encode(data)}');
      }

      // Выполнение POST запроса
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: headers,
        body: json.encode(data),
      );

      if (kDebugMode) {
        print('Message response status: ${response.statusCode}');
        print('Message response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        // Успешный ответ
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return responseData;
      } else {
        // Обработка ошибки
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        return {
          'error': errorData['error']?['message'] ?? 'Unknown error occurred'
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      return {'error': e.toString()};
    }
  }

  // Метод получения текущего баланса
  Future<String> getBalance() async {
    // Проверяем готовность клиента
    if (!isReady) {
      if (kDebugMode) {
        print('OpenRouterClient not ready for getting balance');
      }
      updateFromSettings();
      
      if (!isReady) {
        return 'Не настроено';
      }
    }

    try {
      // Выполнение GET запроса для получения баланса
      final response = await http.get(
        Uri.parse(baseUrl?.contains('vsetgpt.ru') == true
            ? '$baseUrl/balance'
            : '$baseUrl/credits'),
        headers: headers,
      );

      if (kDebugMode) {
        print('Balance response status: ${response.statusCode}');
        print('Balance response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        // Парсинг данных о балансе
        final data = json.decode(response.body);
        if (data != null && data['data'] != null) {
          if (baseUrl?.contains('vsetgpt.ru') == true) {
            final credits =
                double.tryParse(data['data']['credits'].toString()) ??
                    0.0; // Доступно средств
            return '${credits.toStringAsFixed(2)}₽'; // Расчет доступного баланса
          } else {
            final credits = data['data']['total_credits'] ?? 0; // Общие кредиты
            final usage =
                data['data']['total_usage'] ?? 0; // Использованные кредиты
            return '\$${(credits - usage).toStringAsFixed(2)}'; // Расчет доступного баланса
          }
        }
      }
      return baseUrl?.contains('vsetgpt.ru') == true
          ? '0.00₽'
          : '\$0.00'; // Возвращение нулевого баланса по умолчанию
    } catch (e) {
      if (kDebugMode) {
        print('Error getting balance: $e');
      }
      return 'Ошибка'; // Возвращение ошибки в случае исключения
    }
  }

  // Метод форматирования цен
  String formatPricing(double pricing) {
    try {
      if (baseUrl?.contains('vsetgpt.ru') == true) {
        return '${pricing.toStringAsFixed(3)}₽/K';
      } else {
        return '\$${(pricing * 1000000).toStringAsFixed(3)}/M';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting pricing: $e');
      }
      return '0.00';
    }
  }
}
