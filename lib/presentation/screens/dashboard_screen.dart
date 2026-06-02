import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:opa_app/presentation/providers/analytics_provider.dart';
import 'package:opa_app/presentation/widgets/analytics_card.dart';
import 'package:opa_app/presentation/widgets/production_chart.dart';
import 'package:opa_app/presentation/widgets/inspection_pie_chart.dart';
import 'package:opa_app/presentation/widgets/top_blocks_list.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await ref.read(analyticsProvider.notifier).loadDashboardData(
      _dateRange.start,
      _dateRange.end,
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      await _loadDashboardData();
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadDashboardData();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(analyticsProvider);
    final realtimeState = ref.watch(realtimeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: dashboardState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Real-time stats row
                    _buildRealtimeStats(realtimeState),
                    
                    const SizedBox(height: 24),
                    
                    // Summary cards
                    _buildSummaryCards(dashboardState),
                    
                    const SizedBox(height: 24),
                    
                    // Production chart
                    ProductionChart(
                      data: dashboardState.productionData,
                      title: 'Produksi Harian (Ton)',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Two column layout for medium+ screens
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InspectionPieChart(
                                  conditionCount: dashboardState.conditionCount,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TopBlocksList(
                                  blocks: dashboardState.topBlocks,
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            InspectionPieChart(
                              conditionCount: dashboardState.conditionCount,
                            ),
                            const SizedBox(height: 24),
                            TopBlocksList(
                              blocks: dashboardState.topBlocks,
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Monthly trend chart
                    _buildMonthlyTrend(dashboardState),
                    
                    const SizedBox(height: 24),
                    
                    // Task status
                    _buildTaskStatus(dashboardState),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => _buildQuickActionSheet(),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRealtimeStats(dynamic realtimeState) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hari Ini',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRealtimeStat(
                  'Produksi',
                  '${realtimeState.todayProduction?.toStringAsFixed(1) ?? '0'} ton',
                  Icons.agriculture,
                  Colors.orange,
                ),
                _buildRealtimeStat(
                  'Tugas Hari Ini',
                  '${realtimeState.todayTasks ?? 0}',
                  Icons.assignment,
                  Colors.blue,
                ),
                _buildRealtimeStat(
                  'Tugas Tertunda',
                  '${realtimeState.pendingTasks ?? 0}',
                  Icons.warning,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(dynamic state) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        AnalyticsCard(
          title: 'Total Produksi',
          value: '${state.totalProduction?.toStringAsFixed(1) ?? '0'} ton',
          subtitle: '${state.totalRecords ?? 0} kali panen',
          icon: Icons.agriculture,
          color: Colors.green,
          trend: state.productionTrend,
        ),
        AnalyticsCard(
          title: 'Rata-rata Harian',
          value: '${state.averagePerDay?.toStringAsFixed(1) ?? '0'} ton/hari',
          subtitle: 'Periode ini',
          icon: Icons.trending_up,
          color: Colors.blue,
        ),
        AnalyticsCard(
          title: 'Inspeksi',
          value: '${state.totalInspections ?? 0}',
          subtitle: '${state.healthyPercentage?.toStringAsFixed(0) ?? 0}% sehat',
          icon: Icons.visibility,
          color: Colors.purple,
        ),
        AnalyticsCard(
          title: 'Tugas Selesai',
          value: '${state.completedTasks ?? 0}/${state.totalTasks ?? 0}',
          subtitle: '${state.completionRate?.toStringAsFixed(0) ?? 0}%',
          icon: Icons.check_circle,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMonthlyTrend(dynamic state) {
    if (state.monthlyTrend == null || state.monthlyTrend.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tren Produksi Bulanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: state.monthlyTrend.fold<double>(
                    0,
                    (max, item) => item['tonase'] > max ? item['tonase'] : max,
                  ) * 1.1,
                  barGroups: state.monthlyTrend.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: item['tonase'],
                          color: Colors.green,
                          width: 30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < state.monthlyTrend.length) {
                            final monthStr = state.monthlyTrend[index]['month'];
                            final parts = monthStr.split('-');
                            if (parts.length == 2) {
                              return Text(
                                DateFormat('MMM').format(DateTime(int.parse(parts[0]), int.parse(parts[1]))),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskStatus(dynamic state) {
    final taskData = state.taskByType;
    if (taskData == null || taskData.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribusi Tugas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: taskData.entries.map((entry) {
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: entry.key,
                      color: _getTaskColor(entry.key),
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTaskColor(String type) {
    switch (type) {
      case 'FERTILIZATION':
        return Colors.brown;
      case 'PEST_CONTROL':
        return Colors.red;
      case 'INSPECTION':
        return Colors.blue;
      case 'HARVEST':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildQuickActionSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Aksi Cepat',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(
                icon: Icons.visibility,
                label: 'Inspeksi',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/inspection-form');
                },
              ),
              _buildQuickAction(
                icon: Icons.agriculture,
                label: 'Panen',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/harvest-form');
                },
              ),
              _buildQuickAction(
                icon: Icons.science,
                label: 'Pupuk',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/fertilization-form');
                },
              ),
              _buildQuickAction(
                icon: Icons.receipt,
                label: 'Laporan',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/reports');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}