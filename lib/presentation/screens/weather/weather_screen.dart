import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:opa_app/services/weather_service.dart';

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  
  Map<String, dynamic>? _currentWeather;
  List<Map<String, dynamic>>? _forecast;
  List<Map<String, dynamic>>? _yieldPredictions;
  List<Map<String, dynamic>>? _alerts;
  
  bool _isLoading = true;
  String? _selectedBlockId;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    setState(() => _isLoading = true);
    
    try {
      final location = await _weatherService.getCurrentLocation();
      final weather = await _weatherService.getCurrentWeather(location.lat, location.lon);
      final forecast = await _weatherService.getForecast(location.lat, location.lon);
      final predictions = await _weatherService.predictHarvestYield();
      final alerts = await _weatherService.getWeatherAlerts();
      
      setState(() {
        _currentWeather = weather;
        _forecast = forecast;
        _yieldPredictions = predictions;
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data cuaca: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuaca & Prediksi Panen'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeatherData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current weather card
                  _buildCurrentWeatherCard(),
                  
                  const SizedBox(height: 16),
                  
                  // Weather alerts
                  if (_alerts != null && _alerts!.isNotEmpty)
                    _buildAlertsCard(),
                  
                  const SizedBox(height: 16),
                  
                  // 7-day forecast
                  _buildForecastCard(),
                  
                  const SizedBox(height: 16),
                  
                  // Yield predictions
                  _buildYieldPredictionCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentWeatherCard() {
    if (_currentWeather == null) return const SizedBox();
    
    final weather = _currentWeather!;
    final date = DateFormat('EEEE, dd MMMM yyyy', 'id').format(DateTime.now());
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade800, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                date,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://openweathermap.org/img/wn/${weather['icon']}@4x.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weather['temperature'].toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        weather['weather'],
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeatherDetail(
                    Icons.water_drop,
                    'Kelembaban',
                    '${weather['humidity']}%',
                  ),
                  _buildWeatherDetail(
                    Icons.air,
                    'Angin',
                    '${weather['windSpeed']} km/h',
                  ),
                  _buildWeatherDetail(
                    Icons.umbrella,
                    'Hujan',
                    '${weather['rain']} mm',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildAlertsCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Peringatan Cuaca',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._alerts!.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: alert['severity'] == 'HIGH' ? Colors.red : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(alert['message'])),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastCard() {
    if (_forecast == null) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prakiraan 7 Hari',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _forecast!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final day = _forecast![index];
                  final date = DateTime.parse(day['date']);
                  
                  return Column(
                    children: [
                      Text(
                        DateFormat('E', 'id').format(date),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Image.network(
                        'https://openweathermap.org/img/wn/${day['icon']}.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(height: 4),
                      Text('${day['temperature']['max'].toStringAsFixed(0)}°'),
                      Text(
                        '${day['temperature']['min'].toStringAsFixed(0)}°',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYieldPredictionCard() {
    if (_yieldPredictions == null || _yieldPredictions!.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prediksi Hasil Panen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Berdasarkan data historis dan prakiraan cuaca',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Block selector
            if (_yieldPredictions!.length > 1)
              DropdownButtonFormField<String>(
                value: _selectedBlockId,
                decoration: const InputDecoration(
                  labelText: 'Pilih Blok',
                  border: OutlineInputBorder(),
                ),
                items: _yieldPredictions!.map((p) {
                  return DropdownMenuItem(
                    value: p['blockId'],
                    child: Text(p['blockName']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedBlockId = value);
                },
              ),
            
            const SizedBox(height: 16),
            
            // Prediction chart
            if (_selectedBlockId != null || _yieldPredictions!.length == 1)
              _buildPredictionChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionChart() {
    final prediction = _yieldPredictions!.firstWhere(
      (p) => p['blockId'] == (_selectedBlockId ?? _yieldPredictions!.first['blockId']),
    );
    
    final dailyPredictions = List<Map<String, dynamic>>.from(prediction['dailyPredictions']);
    
    return Column(
      children: [
        Container(
          height: 200,
          padding: const EdgeInsets.only(top: 16),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < dailyPredictions.length) {
                        final date = DateTime.parse(dailyPredictions[index]['date']);
                        return Text(
                          DateFormat('dd/MM', 'id').format(date),
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: dailyPredictions.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      entry.value['predictedYield'],
                    );
                  }).toList(),
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withOpacity(0.1),
                  ),
                ),
              ],
              minY: 0,
              maxY: dailyPredictions.fold<double>(
                0,
                (max, p) => p['predictedYield'] > max ? p['predictedYield'] : max,
              ) * 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Prediksi Panen',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '${prediction['totalPredictedYield'].toStringAsFixed(1)} ton',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'vs ${prediction['historicalAvgYield'].toStringAsFixed(1)} ton',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}