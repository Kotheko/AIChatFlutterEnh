// Импорт основных виджетов Flutter
import 'package:flutter/material.dart';
// Импорт для работы с провайдерами состояния
import 'package:provider/provider.dart';
// Импорт провайдера чата
import '../providers/chat_provider.dart';
// Импорт библиотеки для графиков
import 'package:fl_chart/fl_chart.dart';
// Импорт для генерации случайных чисел
import 'dart:math';
// Импорт сервиса данных
//import '../services/data_service.dart';

// Цвета для календаря
const Color _calendarMonthColor = Color(0xFF4A90D9); // Приглушённый синий для месяцев с данными
const Color _selectedMonthColor = Color(0xFF0066FF); // Яркий синий для выбранного месяца

// Виджет экрана расходов
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  // Выбранная модель в выпадающем списке
  String? _selectedModel;
  
  // Список моделей, от которых были получены ответные сообщения
  List<String> _availableModels = [];
  
  // Данные расходов по дням: Map<modelId, Map<date, cost>>
  final Map<String, Map<DateTime, double>> _expensesData = {};
  
  // Флаг загрузки данных
  bool _isLoading = true;
  
  // Scroll controller для графика
  final ScrollController _scrollController = ScrollController();
  
  // Выбранный год в календаре
  int? _selectedYear;
  
  // Выбранный месяц на графике (для подсветки)
  int? _selectedMonth;
  
  // Количество дней для генерации тестовых данных
  static const int _testDays = 450;
  
  // GlobalKey для доступа к размерам графика
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadExpensesData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Генерация тестовых данных
  void _generateTestData() {
    final random = Random(42); // Фиксированный seed для воспроизводимости
    final now = DateTime.now();
    final defaultModel = 'AI21: Jamba Large 1.7';
    
    // Инициализация карты для модели
    _expensesData[defaultModel] = {};
    
    // Генерация данных за последние 450 дней
    // Целевые месяцы с данными: каждые 3 месяца активности
    final Set<int> activeMonths = {};
    for (int i = 0; i < _testDays; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      
      // Каждые 3 месяца активности, 1 месяц простоя
      final monthsAgo = i ~/ 30;
      if (monthsAgo % 4 < 3) {
        activeMonths.add(date.month);
      }
    }
    
    for (int i = 0; i < _testDays; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      
      // 70% шанс что в активный месяц были расходы
      if (activeMonths.contains(date.month) && random.nextDouble() < 0.7) {
        final cost = 0.01 + random.nextDouble() * 4.99;
        _expensesData[defaultModel]![DateTime(date.year, date.month, date.day)] = cost;
      }
    }
    
    // Также добавим небольшие расходы для пары других моделей для демонстрации
    final otherModels = ['google/gemini-pro', 'anthropic/claude-3-opus'];
    for (final model in otherModels) {
      _expensesData[model] = {};
      for (int i = 0; i < 90 + random.nextInt(60); i++) {
        final date = DateTime(now.year, now.month, now.day - i);
        final dateKey = DateTime(date.year, date.month, date.day);
        
        // 30% шанс что в этот день были расходы
        if (random.nextDouble() < 0.3) {
          final cost = 0.01 + random.nextDouble() * 2.0;
          _expensesData[model]![dateKey] = cost;
        }
      }
    }
    
    // Генерация общих расходов
    _expensesData['_total'] = {};
    for (int i = 0; i < _testDays; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dateKey = DateTime(date.year, date.month, date.day);
      
      double totalCost = 0;
      for (final modelData in _expensesData.entries) {
        if (modelData.key != '_total' && modelData.value.containsKey(dateKey)) {
          totalCost += modelData.value[dateKey]!;
        }
      }
      
      if (totalCost > 0) {
        _expensesData['_total']![dateKey] = totalCost;
      }
    }
  }

  // Загрузка и расчет данных расходов
  Future<void> _loadExpensesData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      final messages = chatProvider.messages;

      // Генерация тестовых данных
      _generateTestData();
      
      // Множество моделей с ответными сообщениями
      final Set<String> modelsWithResponses = {};
      
      // Проход по всем сообщениям для сбора моделей
      for (final message in messages) {
        if (!message.isUser && message.modelId != null) {
          modelsWithResponses.add(message.modelId!);
        }
      }
      
      // Добавляем модели из тестовых данных
      for (final modelId in _expensesData.keys) {
        if (modelId != '_total') {
          modelsWithResponses.add(modelId);
        }
      }

      // Определяем текущий месяц для отображения
      final now = DateTime.now();
      _selectedYear = now.year;
      _selectedMonth = now.month;

      setState(() {
        _availableModels = modelsWithResponses.toList()..sort();
        // Добавляем "Общие расходы" в начало списка
        _availableModels.insert(0, '_total');
        
        // Автоматически выбираем "Общие расходы"
        _selectedModel = '_total';
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading expenses data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Получение дней в выбранном месяце
  int _getDaysInMonth() {
    if (_selectedYear == null || _selectedMonth == null) {
      return 30;
    }
    return DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
  }

  // Вычисление ширины столбца на основе доступной ширины
  double _calculateBarWidth(double availableWidth, int daysInMonth) {
    const double spacing = 2.0; // Расстояние между столбцами и по краям
    // (availableWidth - spacing * (groups + 1)) / groups
    final double totalSpacing = spacing * (daysInMonth + 1);
    final double barWidth = (availableWidth - totalSpacing) / daysInMonth;
    return barWidth.clamp(2.0, 20.0); // Минимум 2, максимум 20 пикселей
  }

  // Получение данных для графика выбранного месяца
  List<BarChartGroupData> _getChartData(double barWidth) {
    if (_selectedModel == null || !_expensesData.containsKey(_selectedModel)) {
      return [];
    }
    
    final modelData = _expensesData[_selectedModel]!;
    final daysInMonth = _getDaysInMonth();
    
    final List<BarChartGroupData> barGroups = [];
    
    // Проходим по всем дням месяца
    for (int day = 1; day <= daysInMonth; day++) {
      final dateKey = DateTime(_selectedYear!, _selectedMonth!, day);
      final cost = modelData[dateKey] ?? 0.0;
      
      barGroups.add(
        BarChartGroupData(
          x: day - 1, // Индекс от 0
          barRods: [
            BarChartRodData(
              toY: cost,
              color: Colors.blue,
              width: barWidth,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                topRight: Radius.circular(2),
              ),
            ),
          ],
        ),
      );
    }
    
    return barGroups;
  }

  // Получение максимального значения Y для графика
  double _getMaxY() {
    if (_selectedModel == null || !_expensesData.containsKey(_selectedModel)) {
      return 5.0;
    }
    
    final modelData = _expensesData[_selectedModel]!;
    final daysInMonth = _getDaysInMonth();
    double maxCost = 0;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final dateKey = DateTime(_selectedYear!, _selectedMonth!, day);
      if (modelData.containsKey(dateKey)) {
        final cost = modelData[dateKey]!;
        if (cost > maxCost) {
          maxCost = cost;
        }
      }
    }
    
    // Если нет данных, возвращаем минимальное значение
    if (maxCost <= 0) {
      return 5.0;
    }
    
    // Округляем до ближайшего большего значения
    return (maxCost * 1.2).ceilToDouble() + 1;
  }

  // Получение названия месяца на русском
  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }

  // Получение месяцев с данными для конкретного года
  Set<int> _getMonthsWithDataForYear(int year) {
    if (_selectedModel == null || !_expensesData.containsKey(_selectedModel)) {
      return {};
    }
    
    final modelData = _expensesData[_selectedModel]!;
    final months = <int>{};
    
    for (final date in modelData.keys) {
      if (date.year == year) {
        months.add(date.month);
      }
    }
    
    return months;
  }

  // Получение лет с данными
  List<int> _getYearsWithData() {
    if (_selectedModel == null || !_expensesData.containsKey(_selectedModel)) {
      return [];
    }
    
    final modelData = _expensesData[_selectedModel]!;
    final years = <int>{};
    
    for (final date in modelData.keys) {
      years.add(date.year);
    }
    
    final yearsList = years.toList()..sort((a, b) => b.compareTo(a)); // От новых к старым
    return yearsList;
  }

  // Переход к месяцу
  void _goToMonth(int year, int month) {
    setState(() {
      _selectedYear = year;
      _selectedMonth = month;
    });
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
            : _buildExpensesContent(),
      ),
    );
  }

  // Построение контента со статистикой расходов
  Widget _buildExpensesContent() {
    final monthName = _selectedYear != null && _selectedMonth != null
        ? '${_getMonthName(_selectedMonth!)} $_selectedYear'
        : '';
    
    return Row(
      children: [
        // Основная часть с графиком
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок
                Center(
                  child: Text(
                    'Расходы${monthName.isNotEmpty ? ' - $monthName' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Выпадающий список моделей
                _buildModelDropdown(),
                const SizedBox(height: 24),

                // График
                SizedBox(
                  key: _chartKey,
                  height: 350,
                  child: _buildBarChart(),
                ),
              ],
            ),
          ),
        ),
        
        // Правая панель с календарем
        Container(
          width: 200,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: _buildCalendarPanel(),
        ),
      ],
    );
  }

  // Построение выпадающего списка моделей
  Widget _buildModelDropdown() {
    return Row(
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
                final displayName = model == '_total' ? 'Общие расходы' : model;
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // Построение столбчатой диаграммы
  Widget _buildBarChart() {
    final daysInMonth = _getDaysInMonth();
    final maxY = _getMaxY();
    
    // Безопасный интервал для оси Y
    final double interval = maxY > 0 ? maxY / 5 : 1.0;
    
    // Вычисляем ширину столбца на основе доступной ширины
    // Используем LayoutBuilder для получения доступной ширины
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final barWidth = _calculateBarWidth(availableWidth, daysInMonth);
        final chartData = _getChartData(barWidth);
        
        if (chartData.isEmpty) {
          return const Center(
            child: Text(
              'Нет данных для отображения',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            minY: 0,
            groupsSpace: 2,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF333333),
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final day = group.x + 1;
                  return BarTooltipItem(
                    '${day.toString().padLeft(2, '0')}.${_selectedMonth.toString().padLeft(2, '0')}.$_selectedYear\n\$${rod.toY.toStringAsFixed(2)}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final day = value.toInt() + 1;
                    // Показываем каждые 5 дней
                    if (day % 5 == 0 || day == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          day.toString(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  interval: interval,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '\$${value.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.white.withValues(alpha: 0.1),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            barGroups: chartData,
          ),
        );
      },
    );
  }

  // Построение панели с календарем
  Widget _buildCalendarPanel() {
    final yearsWithData = _getYearsWithData();
    
    // Инициализируем выбранный год если не установлен
    if (_selectedYear == null && yearsWithData.isNotEmpty) {
      _selectedYear = yearsWithData.first; // Самый новый год
    }
    
    // Получаем месяцы для выбранного года
    final monthsForYear = _selectedYear != null 
        ? _getMonthsWithDataForYear(_selectedYear!)
        : <int>{};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Календарь',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        if (yearsWithData.isNotEmpty) ...[
          // Выпадающий список годов
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: _selectedYear,
              dropdownColor: const Color(0xFF333333),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              isExpanded: true,
              underline: Container(height: 1, color: Colors.blue),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  final monthsInYear = _getMonthsWithDataForYear(newValue);
                  int? newMonth;
                  if (_selectedMonth != null && monthsInYear.contains(_selectedMonth)) {
                    newMonth = _selectedMonth;
                  } else if (monthsInYear.isNotEmpty) {
                    newMonth = monthsInYear.first;
                  }
                  _goToMonth(newValue, newMonth ?? 1);
                }
              },
              items: yearsWithData.map((year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Сетка месяцев
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final hasData = monthsForYear.contains(month);
                // Выбранный месяц - это тот, который我们现在 отображаем на графике
                final isSelected = month == _selectedMonth && _selectedYear == _selectedYear;
                
                return InkWell(
                  onTap: hasData && _selectedYear != null
                      ? () {
                          _goToMonth(_selectedYear!, month);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedMonthColor.withValues(alpha: 0.8)
                          : hasData
                              ? _calendarMonthColor.withValues(alpha: 0.3)
                              : const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: _selectedMonthColor, width: 2)
                          : hasData
                              ? Border.all(color: _calendarMonthColor, width: 1)
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        _getMonthName(month).substring(0, 3),
                        style: TextStyle(
                          color: hasData ? Colors.white : Colors.white30,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          const Expanded(
            child: Center(
              child: Text(
                'Нет данных',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Легенда
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Легенда:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _selectedMonthColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: _selectedMonthColor, width: 1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Выбранный',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _calendarMonthColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: _calendarMonthColor, width: 1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'С данными',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Без данных',
                    style: TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
