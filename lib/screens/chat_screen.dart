// Импорт основных виджетов Flutter
import 'package:flutter/material.dart';
// Импорт для работы с системными сервисами (буфер обмена)
import 'package:flutter/services.dart';
// Импорт для работы с провайдерами состояния
import 'package:provider/provider.dart';
// Импорт провайдера чата
import '../providers/chat_provider.dart';
// Импорт модели сообщения
import '../models/message.dart';
// Импорт сервиса настроек
import '../services/settings_service.dart';
// Импорт сервиса данных
import '../services/data_service.dart';
// Импорт API клиента
import '../api/openrouter_client.dart';
// Импорт экрана статистики
import 'statistics_screen.dart';
// Импорт экрана расходов
import 'expenses_screen.dart';

// Виджет для обработки ошибок в UI
class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          debugPrint('Error in ErrorBoundary: $error');
          debugPrint('Stack trace: $stackTrace');
          return Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red,
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }
      },
    );
  }
}

// Виджет для отображения отдельного сообщения в чате
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final List<ChatMessage> messages;
  final int index;

  const _MessageBubble({
    required this.message,
    required this.messages,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: message.isUser
                  ? const Color(0xFF1A73E8)
                  : const Color(0xFF424242),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              message.cleanContent,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          if (message.tokens != null || message.cost != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.tokens != null)
                    Text(
                      'Токенов: ${message.tokens}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  if (message.tokens != null && message.cost != null)
                    const SizedBox(width: 8),
                  if (message.cost != null)
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, child) {
                        final isVsetgpt =
                            chatProvider.baseUrl?.contains('vsetgpt.ru') ==
                                true;
                        return Text(
                          message.cost! < 0.001
                              ? isVsetgpt
                                  ? 'Стоимость: <0.001₽'
                                  : 'Стоимость: <\$0.001'
                              : isVsetgpt
                                  ? 'Стоимость: ${message.cost!.toStringAsFixed(3)}₽'
                                  : 'Стоимость: \$${message.cost!.toStringAsFixed(3)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    color: Colors.white54,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: () {
                      final textToCopy = message.isUser
                          ? message.cleanContent
                          : '${messages[index - 1].cleanContent}\n\n${message.cleanContent}';
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Текст скопирован',
                              style: TextStyle(fontSize: 12)),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: 'Копировать текст',
                  ),
                  const Spacer()
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Виджет для ввода сообщений
class _MessageInput extends StatefulWidget {
  final void Function(String) onSubmitted;

  const _MessageInput({required this.onSubmitted});

  @override
  _MessageInputState createState() => _MessageInputState();
}

// Состояние виджета ввода сообщений
class _MessageInputState extends State<_MessageInput> {
  // Контроллер для управления текстовым полем
  final _controller = TextEditingController();
  // Флаг, указывающий, вводится ли сейчас сообщение
  bool _isComposing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
    widget.onSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (String text) {
                setState(() {
                  _isComposing = text.trim().isNotEmpty;
                });
              },
              onSubmitted: _isComposing ? _handleSubmitted : null,
              decoration: const InputDecoration(
                hintText: 'Введите сообщение...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            color: _isComposing ? Colors.blue : Colors.grey,
            onPressed:
                _isComposing ? () => _handleSubmitted(_controller.text) : null,
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

// Основной экран чата с вкладками
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Контроллер для текстовых полей настроек
  final _apiKeyController = TextEditingController();
  final _modelSearchController = TextEditingController();
  
  // Контроллер для прокрутки списка сообщений
  final ScrollController _scrollController = ScrollController();
  
  // Список моделей для фильтрации
  List<Map<String, dynamic>> _allModels = [];
  List<Map<String, dynamic>> _filteredModels = [];
  
  // Выбранная модель
  String? _selectedModel;
  
  // Выбранный сервис
  String _selectedService = SettingsService.defaultBaseUrl;
  
  // Состояние загрузки
  bool _isApplyingSettings = false;
  
  // Флаг первичной инициализации
  bool _initialized = false;
  
  // Последний известный поисковый запрос
  String _lastQuery = '';
  
  // Флаг загрузки моделей (для отложенной установки сохраненной модели)
  bool _modelsLoaded = false;
  
  // Сохраненная модель для отложенной установки
  String? _pendingSavedModel;
  
  // Количество сообщений для отслеживания изменений
  int _previousMessageCount = 0;
  
  // Флаг удаления API ключа при выходе
  bool _deleteApiKeyOnExit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _selectedService = SettingsService.defaultBaseUrl;
    
    // Добавляем слушатель для поиска моделей
    _modelSearchController.addListener(_onSearchChanged);
    
    // Загружаем сохраненную модель (не применяем сразу)
    _loadSavedModel();
  }
  
  // Обработчик жизненного цикла приложения
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _onAppExit();
    }
  }
  
  // Действия при выходе из приложения
  Future<void> _onAppExit() async {
    if (_deleteApiKeyOnExit) {
      final settings = SettingsService();
      await settings.clearApiKey();
      debugPrint('API key cleared on app exit');
    }
  }
  
  // Загрузка сохраненной модели (без немедленного применения)
  Future<void> _loadSavedModel() async {
    try {
      final dataService = DataService();
      final savedModel = await dataService.loadSelectedModel();
      if (savedModel != null && mounted) {
        // Сохраняем модель для последующего применения после загрузки списка моделей
        _pendingSavedModel = savedModel;
      }
    } catch (e) {
      debugPrint('Error loading saved model: $e');
    }
  }
  
  // Применение сохраненной модели после загрузки списка
  void _applyPendingModel() {
    if (_pendingSavedModel != null && _modelsLoaded) {
      // Проверяем, есть ли модель в текущем списке
      final modelExists = _allModels.any(
        (model) => model['id'] == _pendingSavedModel
      );
      
      if (modelExists && mounted) {
        setState(() {
          _selectedModel = _pendingSavedModel;
        });
        context.read<ChatProvider>().setCurrentModel(_pendingSavedModel!);
      }
      _pendingSavedModel = null;
    }
  }
  
  // Обработчик изменения текста поиска
  void _onSearchChanged() {
    final currentQuery = _modelSearchController.text;
    // Проверяем, изменился ли запрос
    if (currentQuery != _lastQuery) {
      _lastQuery = currentQuery;
      _filterModels();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _apiKeyController.dispose();
    _modelSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Инициализация данных
  Future<void> _initializeSettings() async {
    if (_initialized) return;
    _initialized = true;
    
    final settings = SettingsService();
    
    // Загружаем сохраненные настройки
    if (settings.apiKey != null && settings.apiKey!.isNotEmpty) {
      _apiKeyController.text = settings.apiKey!;
    }
    
    if (settings.selectedService.isNotEmpty) {
      _selectedService = settings.selectedService;
    }
    
    if (settings.selectedModel != null) {
      _selectedModel = settings.selectedModel;
    }
    
    // Загружаем флаг удаления API ключа при выходе
    _deleteApiKeyOnExit = settings.deleteApiKeyOnExit;
  }

  // Фильтрация моделей по поисковому запросу
  void _filterModels() {
    final query = _modelSearchController.text.trim().toLowerCase();
    setState(() {
      // Всегда фильтруем по полному списку моделей
      if (query.isEmpty) {
        _filteredModels = _allModels;
      } else {
        _filteredModels = _allModels.where((model) {
          final name = (model['name'] as String? ?? '').toLowerCase();
          final id = (model['id'] as String? ?? '').toLowerCase();
          return name.contains(query) || id.contains(query);
        }).toList();
        
        // Сбрасываем выбор если выбранная модель не входит в результаты поиска
        if (_selectedModel != null && _filteredModels.isNotEmpty) {
          final selectedInFiltered = _filteredModels.any(
            (model) => model['id'] == _selectedModel
          );
          if (!selectedInFiltered) {
            _selectedModel = null;
          }
        }
      }
    });
  }

  // Применение настроек
  Future<void> _applySettings() async {
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Введите ключ API', style: TextStyle(fontSize: 12)),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isApplyingSettings = true;
    });

    try {
      // Сохраняем настройки
      final settings = SettingsService();
      await settings.saveSettings(
        apiKey: apiKey,
        baseUrl: _selectedService,
        selectedModel: _selectedModel,
      );

      // Обновляем API клиент
      final apiClient = OpenRouterClient();
      apiClient.updateFromSettings();

      // Загружаем модели
      final models = await apiClient.getModels();

      // Обновляем состояние с новыми моделями
      if (mounted) {
        setState(() {
          _allModels = models;
          _filteredModels = models;
          _modelsLoaded = true;
        });
        
        // Применяем сохраненную модель после загрузки списка моделей
        _applyPendingModel();
        
        // Обновляем ChatProvider для загрузки новых данных
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.refreshData();
        
        // Устанавливаем выбранную модель
        if (_selectedModel != null) {
          chatProvider.setCurrentModel(_selectedModel!);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Подключено', style: TextStyle(fontSize: 12)),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e', style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isApplyingSettings = false;
      });
    }
  }

  // Виджет вкладки "Главная страница"
  Widget _buildHomePage() {
    return ErrorBoundary(
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _buildMessagesList(),
              ),
              _buildInputArea(context),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  // Виджет вкладки "Настройки"
  Widget _buildSettingsPage() {
    // Инициализируем данные при первом показе страницы
    _initializeSettings();
    
    return ErrorBoundary(
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Первый ряд: Заголовок "Настройки подключения"
                const Center(
                  child: Text(
                    'Настройки подключения',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Второй ряд: API ключ
                Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Введите ключ API:',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Введите ключ...',
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF333333),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Чекбокс для удаления API ключа при выходе
                Row(
                  children: [
                    const Expanded(flex: 2, child: SizedBox()),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _deleteApiKeyOnExit,
                              onChanged: (value) {
                                setState(() {
                                  _deleteApiKeyOnExit = value ?? false;
                                });
                                final settings = SettingsService();
                                settings.deleteApiKeyOnExit = _deleteApiKeyOnExit;
                              },
                              activeColor: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Удалить ключ API при выходе из приложения',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Третий ряд: Выбор сервиса
                Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Выберите сервис:',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedService,
                          hint: const Text(
                            'Выберите сервис',
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
                            if (newValue != null) {
                              setState(() {
                                _selectedService = newValue;
                              });
                              final settings = SettingsService();
                              settings.selectedService = newValue;
                            }
                          },
                          items: SettingsService.availableServices.map((service) {
                            String displayName;
                            if (service.contains('openrouter')) {
                              displayName = 'OpenRouter';
                            } else if (service.contains('vsetgpt')) {
                              displayName = 'VsetGPT';
                            } else {
                              displayName = service;
                            }
                            return DropdownMenuItem<String>(
                              value: service,
                              child: Text(
                                displayName,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Четвертый ряд: Кнопка "Подключить"
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _isApplyingSettings ? null : _applySettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: _isApplyingSettings
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Подключить'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Пятый ряд: Заголовок "Выбор модели"
                const Center(
                  child: Text(
                    'Выбор модели',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Шестой ряд: Поиск и выпадающий список моделей
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Поиск модели:',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _modelSearchController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Поиск...',
                                hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                filled: true,
                                fillColor: const Color(0xFF333333),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Выберите модель:',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
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
                            // Обновляем модель в ChatProvider для отображения в AppBar
                            if (newValue != null) {
                              context.read<ChatProvider>().setCurrentModel(newValue);
                            }
                          },
                          items: _filteredModels.isEmpty
                              ? [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Нажмите "Подключить" для загрузки моделей',
                                      style: TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ),
                                ]
                              : _filteredModels.map((model) {
                                  return DropdownMenuItem<String>(
                                    value: model['id'] as String,
                                    child: Text(
                                      model['name'] ?? model['id'] ?? '',
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
                
                // Текущий статус подключения
                _buildConnectionStatus(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Виджет статуса подключения
  Widget _buildConnectionStatus() {
    final settings = SettingsService();
    final apiClient = OpenRouterClient();
    
    String serviceDisplay = _selectedService;
    if (_selectedService.contains('openrouter')) {
      serviceDisplay = 'OpenRouter';
    } else if (_selectedService.contains('vsetgpt')) {
      serviceDisplay = 'VsetGPT';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Текущий статус:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatusRow('API ключ:', settings.hasApiKey ? 'Настроен' : 'Не настроен', 
              settings.hasApiKey ? Colors.green : Colors.red),
          _buildStatusRow('Сервис:', serviceDisplay, Colors.green),
          _buildStatusRow('Клиент готов:', apiClient.isReady ? 'Да' : 'Нет',
              apiClient.isReady ? Colors.green : Colors.orange),
          _buildStatusRow('Удаление ключа:', _deleteApiKeyOnExit ? 'Включено' : 'Отключено',
              _deleteApiKeyOnExit ? Colors.orange : Colors.grey),
        ],
      ),
    );
  }
  
  Widget _buildStatusRow(String label, String value, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: statusColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF262626),
          toolbarHeight: 48,
          title: Row(
            children: [
              const Text(
                'AI Chat',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              _buildBalanceDisplay(context),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 14),
            tabs: const [
              Tab(text: 'Главная страница'),
              Tab(text: 'Настройки'),
              Tab(text: 'Статистика'),
              Tab(text: 'Расходы'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildHomePage(),
            _buildSettingsPage(),
            const StatisticsScreen(),
            const ExpensesScreen(),
          ],
        ),
      ),
    );
  }

  // Отображение текущего баланса пользователя
  Widget _buildBalanceDisplay(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final settings = SettingsService();
        
        // Если настройки не настроены, показываем сообщение
        if (!settings.hasApiKey || !settings.hasBaseUrl) {
          return const Text(
            '',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          );
        }
        
        final currentModel = chatProvider.currentModel;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentModel != null) ...[
                Flexible(
                  child: Text(
                    currentModel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.credit_card, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                chatProvider.balance,
                style: const TextStyle(
                  color: Color(0xFF33CC33),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Построение списка сообщений чата
  Widget _buildMessagesList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Проверяем, появились ли новые сообщения или загрузились сохраненные
        final currentMessageCount = chatProvider.messages.length;
        if (currentMessageCount > _previousMessageCount || 
            (_previousMessageCount == 0 && currentMessageCount > 0)) {
          _previousMessageCount = currentMessageCount;
          // Прокручиваем к последнему сообщению при появлении новых или загрузке сохраненных
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });
        }
        
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          reverse: false,
          itemCount: chatProvider.messages.length,
          itemBuilder: (context, index) {
            final message = chatProvider.messages[index];
            return _MessageBubble(
              message: message,
              messages: chatProvider.messages,
              index: index,
            );
          },
        );
      },
    );
  }

  // Построение области ввода сообщений
  Widget _buildInputArea(BuildContext context) {
    final settings = SettingsService();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: const Color(0xFF262626),
      child: Column(
        children: [
          // Предупреждение если настройки не настроены
          if (!settings.hasApiKey || !settings.hasBaseUrl)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Настройте подключение во вкладке "Настройки"',
                      style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _MessageInput(
                  onSubmitted: (String text) {
                    if (text.trim().isNotEmpty) {
                      final chatProvider = context.read<ChatProvider>();
                      if (chatProvider.currentModel != null) {
                        chatProvider.sendMessage(text);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Сначала выберите модель в настройках',
                                style: TextStyle(fontSize: 12)),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Получение пути к файлу данных
  Future<String> _getDataFilePath() async {
    final dataService = DataService();
    return await dataService.getDataFilePath();
  }
  
  // Сохранение всех данных приложения
  Future<bool> _saveAllAppData() async {
    try {
      final dataService = DataService();
      final chatProvider = context.read<ChatProvider>();
      
      // Получаем сообщения
      final messages = chatProvider.messages.map((m) => m.toJson()).toList();
      
      // Получаем статистику из базы данных
      final dbStats = await chatProvider.exportHistory();
      
      // Получаем выбранную модель
      final selectedModel = _selectedModel;
      
      // Получаем расходы (пустая структура, так как expenses_screen генерирует тестовые данные)
      final expenses = {
        'test_data': true,
        'generated_at': DateTime.now().toIso8601String(),
      };
      
      // Сохраняем все данные
      final success = await dataService.saveAllData(
        messages: messages,
        statistics: dbStats,
        expenses: expenses,
        selectedModel: selectedModel,
      );
      
      return success;
    } catch (e) {
      debugPrint('Error saving all app data: $e');
      return false;
    }
  }
  
  // Показать диалог сохранения данных
  void _showSaveDataDialog(BuildContext context) async {
    final filePath = await _getDataFilePath();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Сохранить данные?',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Сохранить данные общения и статистики?',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Файл: app_data.json',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  filePath,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Нет', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final success = await _saveAllAppData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success 
                            ? 'Данные сохранены' 
                            : 'Ошибка сохранения данных',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
              ),
              child: const Text('Да', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }
  
  // Построение панели с кнопками действий
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: const Color(0xFF262626),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context: context,
            icon: Icons.save,
            label: 'Сохранить',
            color: const Color(0xFF1A73E8),
            onPressed: () => _showSaveDataDialog(context),
          ),
          _buildActionButton(
            context: context,
            icon: Icons.delete,
            label: 'Очистить',
            color: const Color(0xFFCC3333),
            onPressed: () => _showClearHistoryDialog(context),
          ),
        ],
      ),
    );
  }

  // Создание отдельной кнопки действия с заданными параметрами
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
        ),
      ),
    );
  }

  // Отображение диалога подтверждения очистки истории
  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Очистить историю',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: const Text(
            'Вы уверены? Это действие нельзя отменить.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () {
                context.read<ChatProvider>().clearHistory();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Очистить',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}
