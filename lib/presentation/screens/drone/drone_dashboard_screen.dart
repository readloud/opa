import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:opa_app/services/drone_service.dart';
import 'package:opa_app/presentation/screens/drone/drone_mission_screen.dart';

class DroneDashboardScreen extends ConsumerStatefulWidget {
  const DroneDashboardScreen({super.key});

  @override
  ConsumerState<DroneDashboardScreen> createState() => _DroneDashboardScreenState();
}

class _DroneDashboardScreenState extends ConsumerState<DroneDashboardScreen> {
  final DroneService _droneService = DroneService();
  
  List<Map<String, dynamic>> _missions = [];
  bool _isLoading = true;
  Map<String, dynamic>? _latestHealthStats;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final missions = await _droneService.getMissions();
      setState(() {
        _missions = missions;
        _isLoading = false;
      });
      
      if (missions.isNotEmpty) {
        _loadHealthStats(missions.first['id']);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $e')),
      );
    }
  }

  Future<void> _loadHealthStats(String missionId) async {
    try {
      final report = await _droneService.getMissionReport(missionId);
      setState(() {
        _latestHealthStats = report['healthSummary'];
        _alerts = List<Map<String, dynamic>>.from(report['recommendations'] ?? []);
      });
    } catch (e) {
      print('Failed to load health stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drone Monitoring'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flight_takeoff),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DroneMissionScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
                  // Health overview
                  if (_latestHealthStats != null)
                    _buildHealthOverviewCard(),
                  
                  const SizedBox(height: 16),
                  
                  // Alerts and recommendations
                  if (_alerts.isNotEmpty)
                    _buildAlertsCard(),
                  
                  const SizedBox(height: 16),
                  
                  // Recent missions
                  const Text(
                    'Misi Terbaru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _missions.length > 3 ? 3 : _missions.length,
                    itemBuilder: (context, index) {
                      final mission = _missions[index];
                      return _buildMissionCard(mission);
                    },
                  ),
                  
                  if (_missions.length > 3)
                    TextButton(
                      onPressed: () {
                        // Navigate to all missions
                      },
                      child: const Text('Lihat semua misi'),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _droneService.autoScheduleMission();
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Misi otomatis dijadwalkan')),
          );
        },
        icon: const Icon(Icons.schedule),
        label: const Text('Jadwalkan Misi'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  Widget _buildHealthOverviewCard() {
    final stats = _latestHealthStats!;
    final zones = stats['zones'] ?? {};
    final percentages = stats['percentages'] ?? {};
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview Kesehatan Kebun',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Health score gauge
            Container(
              height: 120,
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    ranges: <GaugeRange>[
                      GaugeRange(startValue: 0, endValue: 40, color: Colors.red),
                      GaugeRange(startValue: 40, endValue: 70, color: Colors.orange),
                      GaugeRange(startValue: 70, endValue: 100, color: Colors.green),
                    ],
                    pointers: <GaugePointer>[
                      NeedlePointer(
                        value: stats['overallHealthScore'] ?? 0,
                        needleColor: Colors.black87,
                      ),
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        widget: Text(
                          '${(stats['overallHealthScore'] ?? 0).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        angle: 90,
                        positionFactor: 0.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Health distribution
            Row(
              children: [
                Expanded(
                  child: _buildHealthLegend('Sehat', percentages['healthy'], Colors.green),
                ),
                Expanded(
                  child: _buildHealthLegend('Sedang', percentages['moderate'], Colors.lightGreen),
                ),
                Expanded(
                  child: _buildHealthLegend('Stres', percentages['stressed'], Colors.yellow),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildHealthLegend('Tidak Sehat', percentages['unhealthy'], Colors.orange),
                ),
                Expanded(
                  child: _buildHealthLegend('Mati', percentages['dead'], Colors.red),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthLegend(String label, String? percentage, Color color) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          '${percentage ?? '0'}%',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAlertsCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Rekomendasi Tindakan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: alert['priority'] == 'URGENT' 
                          ? Colors.red 
                          : alert['priority'] == 'HIGH' 
                              ? Colors.orange 
                              : Colors.blue,
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

  Widget _buildMissionCard(Map<String, dynamic> mission) {
    final date = DateTime.parse(mission['flightDate']);
    final status = mission['status'];
    
    Color statusColor;
    switch (status) {
      case 'COMPLETED':
        statusColor = Colors.green;
        break;
      case 'PROCESSING':
        statusColor = Colors.orange;
        break;
      case 'FAILED':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            status == 'COMPLETED' ? Icons.check : Icons.sync,
            color: statusColor,
          ),
        ),
        title: Text('Misi ${date.toString().split(' ')[0]}'),
        subtitle: Text(
          '${mission['imageCount']} gambar | ${mission['areaCovered']?.toStringAsFixed(1) ?? '?'} Ha',
        ),
        trailing: Chip(
          label: Text(status),
          backgroundColor: statusColor.withOpacity(0.2),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DroneMissionDetailScreen(missionId: mission['id']),
            ),
          );
        },
      ),
    );
  }
}

class DroneMissionDetailScreen extends StatelessWidget {
  final String missionId;

  const DroneMissionDetailScreen({super.key, required this.missionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Misi Drone'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: DroneService().getMissionDetails(missionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final mission = snapshot.data!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NDVI Map
                if (mission['ndviUrl'] != null)
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Peta NDVI',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          child: Image.network(
                            mission['ndviUrl'],
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatRow('Tanggal Penerbangan', 
                            DateTime.parse(mission['flightDate']).toString().split(' ')[0]),
                        _buildStatRow('Jumlah Gambar', mission['imageCount'].toString()),
                        _buildStatRow('Area Tercover', 
                            '${mission['areaCovered']?.toStringAsFixed(1) ?? '?'} Ha'),
                        _buildStatRow('Ketinggian', '${mission['altitude'] ?? '?'} m'),
                        _buildStatRow('Status', mission['status']),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}