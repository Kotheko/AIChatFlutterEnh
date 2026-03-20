// Импорт основных виджетов Flutter
import 'package:flutter/material.dart';
// Импорт для работы с провайдерами состояния
import 'package:provider/provider.dart';
// Импорт провайдера чата
import '../providers/chat_provider.dart';
// Импорт модели сообщения
//import '../models/message.dart';

// Виджет экрана статистики
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Выбранная модель в выпадающем списке
  String? _selectedModel;
  
  // Список моделей, от которых были получены ответные сообщения
  List<String> _availableModels = [];
  
  // Статистика по каждой модели
  Map<String, Map<String, dynamic>> _modelStatistics = {};
  
  // Флаг загрузки данных
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  // Загрузка и расчет статистики
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      final messages = chatProvider.messages;

      // Карта для накопления статистики по моделям
      final Map<String, Map<String, dynamic>> modelStats = {};
      
      // Множество моделей с ответными сообщениями
      final Set<String> modelsWithResponses = {};

      // Проход по всем сообщениям для сбора статистики
      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];
        
        // Проверяем, что это ответное сообщение (не от пользователя и с modelId)
        if (!message.isUser && message.modelId != null) {
          modelsWithResponses.add(message.modelId!);
          
          // Инициализация статистики для модели при первом использовании
          if (!modelStats.containsKey(message.modelId)) {
            modelStats[message.modelId!] = {
              'tokens': 0,
              'messageCount': 0,
              'firstTimestamp': message.timestamp,
              'lastTimestamp': message.timestamp,
            };
          }
          
          // Обновление статистики
          final stats = modelStats[message.modelId]!;
          stats['tokens'] = (stats['tokens'] ?? 0) + (message.tokens ?? 0);
          stats['messageCount'] = (stats['messageCount'] ?? 0) + 1;
          
          // Обновление временных меток
          if (message.timestamp.isBefore(stats['firstTimestamp'])) {
            stats['firstTimestamp'] = message.timestamp;
          }
          if (message.timestamp.isAfter(stats['lastTimestamp'])) {
            stats['lastTimestamp'] = message.timestamp;
          }
        }
      }

      // Расчет производных статистик для каждой модели
      final Map<String, Map<String, dynamic>> calculatedStats = {};
      
      for (final entry in modelStats.entries) {
        final modelId = entry.key;
        final stats = entry.value;
        final messageCount = stats['messageCount'] as int;
        final tokens = stats['tokens'] as int;
        final firstTimestamp = stats['firstTimestamp'] as DateTime;
        final lastTimestamp = stats['lastTimestamp'] as DateTime;
        
        // Расчет времени между первым и последним сообщением в минутах
        final durationMinutes = lastTimestamp.difference(firstTimestamp).inMinutes;
        
        // Расчет среднего количества токенов на сообщение
        final tokensPerMessage = messageCount > 0 ? tokens / messageCount : 0.0;
        
        // Расчет сообщений в минуту (если есть временной диапазон)
        final messagesPerMinute = durationMinutes > 0 
            ? messageCount / durationMinutes 
            : messageCount.toDouble();
        
        calculatedStats[modelId] = {
          'tokens': tokens,
          'messageCount': messageCount,
          'tokensPerMessage': tokensPerMessage,
          'messagesPerMinute': messagesPerMinute,
          'firstTimestamp': firstTimestamp,
          'lastTimestamp': lastTimestamp,
        };
      }

      // Расчет общей статистики по всем моделям
      int totalTokens = 0;
      int totalMessages = 0;
      DateTime? globalFirstTimestamp;
      DateTime? globalLastTimestamp;

      for (final stats in calculatedStats.values) {
        totalTokens += stats['tokens'] as int;
        totalMessages += stats['messageCount'] as int;
        
        final firstTs = stats['firstTimestamp'] as DateTime;
        final lastTs = stats['lastTimestamp'] as DateTime;
        
        if (globalFirstTimestamp == null || firstTs.isBefore(globalFirstTimestamp)) {
          globalFirstTimestamp = firstTs;
        }
        if (globalLastTimestamp == null || lastTs.isAfter(globalLastTimestamp)) {
          globalLastTimestamp = lastTs;
        }
      }

      // Расчет общей статистики
      final globalDurationMinutes = (globalLastTimestamp != null && globalFirstTimestamp != null)
          ? globalLastTimestamp.difference(globalFirstTimestamp).inMinutes
          : 0;
      
      final globalTokensPerMessage = totalMessages > 0 ? totalTokens / totalMessages : 0.0;
      final globalMessagesPerMinute = globalDurationMinutes > 0 
          ? totalMessages / globalDurationMinutes 
          : totalMessages.toDouble();

      // Сохранение общей статистики
      calculatedStats['_global'] = {
        'tokens': totalTokens,
        'messageCount': totalMessages,
        'tokensPerMessage': globalTokensPerMessage,
        'messagesPerMinute': globalMessagesPerMinute,
      };

      setState(() {
        _availableModels = modelsWithResponses.toList()..sort();
        _modelStatistics = calculatedStats;
        
        // Автоматически выбираем первую модель, если она есть
        if (_availableModels.isNotEmpty && _selectedModel == null) {
          _selectedModel = _availableModels.first;
        }
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Форматирование числа токенов
  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(2)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(2)}K';
    }
    return tokens.toString();
  }

  // Форматирование числа с плавающей точкой
  String _formatNumber(double value, {int decimals = 2}) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(decimals)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(decimals)}K';
    }
    return value.toStringAsFixed(decimals);
  }

  // Построение виджета строки статистики
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.blue,
                ),
              )
            : _availableModels.isEmpty
                ? _buildEmptyState()
                : _buildStatisticsContent(),
      ),
    );
  }

  // Виджет для пустого состояния (нет данных)
  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              'Нет данных о статистике',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Отправьте сообщения, чтобы увидеть статистику',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Построение контента со статистикой
  Widget _buildStatisticsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Заголовок "Статистика"
          const Center(
            child: Text(
              'Статистика',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Выпадающий список моделей
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Выберите модель:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedModel,
                    hint: const Text(
                      'Выберите модель',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    dropdownColor: const Color(0xFF333333),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    isExpanded: true,
                    underline: Container(
                      height: 1,
                      color: Colors.blue,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedModel = newValue;
                      });
                    },
                    items: _availableModels.map((model) {
                      return DropdownMenuItem<String>(
                        value: model,
                        child: Text(
                          model,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Статистика для выбранной модели (в столбик)
          if (_selectedModel != null && _modelStatistics.containsKey(_selectedModel)) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Статистика модели: $_selectedModel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildModelStatsColumn(_modelStatistics[_selectedModel]!),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Общая статистика по всем моделям (в строку)
          if (_modelStatistics.containsKey('_global')) ...[
            const Center(
              child: Text(
                'Общая статистика',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildGlobalStatsRow(_modelStatistics['_global']!),
          ],
        ],
      ),
    );
  }

  // Построение статистики модели в столбик
  List<Widget> _buildModelStatsColumn(Map<String, dynamic> stats) {
    final tokens = stats['tokens'] as int;
    final messageCount = stats['messageCount'] as int;
    final tokensPerMessage = stats['tokensPerMessage'] as double;
    final messagesPerMinute = stats['messagesPerMinute'] as double;

    return [
      _buildStatRow('Использовано токенов', _formatTokens(tokens)),
      _buildStatRow('Количество сообщений', messageCount.toString()),
      _buildStatRow('Среднее токенов/сообщение', _formatNumber(tokensPerMessage)),
      _buildStatRow('Сообщений в минуту', _formatNumber(messagesPerMinute)),
    ];
  }

  // Построение общей статистики в строку
  Widget _buildGlobalStatsRow(Map<String, dynamic> stats) {
    final tokens = stats['tokens'] as int;
    final messageCount = stats['messageCount'] as int;
    final tokensPerMessage = stats['tokensPerMessage'] as double;
    final messagesPerMinute = stats['messagesPerMinute'] as double;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 16,
        runSpacing: 8,
        children: [
          _buildGlobalStatItem('Токенов', _formatTokens(tokens)),
          _buildGlobalStatItem('Сообщений', messageCount.toString()),
          _buildGlobalStatItem('Токенов/сообщ', _formatNumber(tokensPerMessage)),
          _buildGlobalStatItem('Сообщ/мин', _formatNumber(messagesPerMinute)),
        ],
      ),
    );
  }

  // Построение элемента общей статистики
  Widget _buildGlobalStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
