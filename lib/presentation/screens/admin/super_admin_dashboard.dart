import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:opa_app/services/admin_service.dart';

class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  final AdminService _adminService = AdminService();
  
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String _selectedEstateId = 'all';
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await _adminService.getMultiEstateDashboard();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat dashboard: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportReport(),
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
                  // Global KPI Cards
                  _buildGlobalKPI(),
                  
                  const SizedBox(height: 24),
                  
                  // Estates performance chart
                  _buildEstatesPerformanceChart(),
                  
                  const SizedBox(height: 24),
                  
                  // Pest summary across estates
                  _buildPestSummary(),
                  
                  const SizedBox(height: 24),
                  
                  // Alerts section
                  _buildAlertsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Estates list
                  _buildEstatesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildGlobalKPI() {
    final summary = _dashboardData?['summary'] as Map? ?? {};
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildKpiCard('Total Estate', '${summary['totalEstates'] ?? 0}', Icons.business, Colors.blue),
        _buildKpiCard('Total Area', '${(summary['totalArea'] ?? 0).toStringAsFixed(0)} Ha', Icons.terrain, Colors.green),
        _buildKpiCard('Total Panen', '${(summary['totalHarvests'] ?? 0).toStringAsFixed(0)} ton', Icons.agriculture, Colors.orange),
        _buildKpiCard('Drone Missions', '${summary['totalDroneMissions'] ?? 0}', Icons.flight, Colors.purple),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstatesPerformanceChart() {
    final estates = _dashboardData?['estates'] as List? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performa Per Estate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                title: ChartTitle(text: 'Health Score by Estate'),
                series: <ChartSeries>[
                  BarSeries<dynamic, String>(
                    dataSource: estates,
                    xValueMapper: (data, _) => data['name'],
                    yValueMapper: (data, _) => data['healthScore'],
                    name: 'Health Score',
                    color: Colors.green,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPestSummary() {
    final pestSummary = _dashboardData?['pestSummary'] as List? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Hama per Estate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pestSummary.length,
                itemBuilder: (context, index) {
                  final estate = pestSummary[index];
                  return Container(
                    width: 250,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              estate['estateName'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Total Detections: ${estate['totalDetections']}'),
                            const SizedBox(height: 4),
                            ...(estate['pests'] as Map).entries.map((entry) {
                              return Text(
                                '• ${entry.key}: ${entry.value}',
                                style: const TextStyle(fontSize: 12),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    final alerts = _dashboardData?['alerts'] as List? ?? [];
    
    if (alerts.isEmpty) return const SizedBox();
    
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Peringatan Global',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) => Padding(
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
                  Expanded(
                    child: Text(
                      alert['estateName'] != null
                          ? '[${alert['estateName']}] ${alert['message']}'
                          : alert['message'],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEstatesList() {
    final estates = _dashboardData?['estates'] as List? ?? [];
    final topPerformers = _dashboardData?['topPerformers'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Estate',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: estates.length,
          itemBuilder: (context, index) {
            final estate = estates[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: estate['healthScore'] > 70 ? Colors.green : Colors.orange,
                  child: Text('${estate['healthScore']}'),
                ),
                title: Text(estate['name']),
                subtitle: Text(
                  'Blocks: ${estate['totalBlocks']} | Workers: ${estate['totalWorkers']} | Area: ${estate['totalArea']} Ha',
                ),
                trailing: Chip(
                  label: Text(
                    estate['lastDroneMission'] != null
                        ? 'Last: ${DateTime.parse(estate['lastDroneMission']).toString().split(' ')[0]}'
                        : 'No mission',
                  ),
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/admin/estate-detail', arguments: estate['id']);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _exportReport() async {
    // Implement export to PDF
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting report...')),
    );
  }
}