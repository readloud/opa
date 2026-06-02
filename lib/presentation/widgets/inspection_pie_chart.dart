import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class InspectionPieChart extends StatelessWidget {
  final Map<String, int>? conditionCount;

  const InspectionPieChart({super.key, required this.conditionCount});

  @override
  Widget build(BuildContext context) {
    if (conditionCount == null || conditionCount!.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Tidak ada data inspeksi')),
        ),
      );
    }

    final total = conditionCount!.values.reduce((a, b) => a + b);
    final sections = <PieChartSectionData>[];

    const colors = [
      Color(0xFF4CAF50), // Healthy - Green
      Color(0xFFFF9800), // Mild Damage - Orange
      Color(0xFFF44336), // Severe Damage - Red
      Color(0xFF9E9E9E), // Dead - Grey
    ];

    const labels = ['Sehat', 'Rusak Ringan', 'Rusak Berat', 'Mati'];
    const keys = ['HEALTHY', 'MILD_DAMAGE', 'SEVERE_DAMAGE', 'DEAD'];

    for (int i = 0; i < keys.length; i++) {
      final count = conditionCount![keys[i]] ?? 0;
      if (count > 0) {
        final percentage = (count / total * 100).toStringAsFixed(1);
        sections.add(
          PieChartSectionData(
            value: count.toDouble(),
            title: '$percentage%',
            color: colors[i],
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kondisi Pohon',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: [
                _buildLegend('Sehat', const Color(0xFF4CAF50)),
                _buildLegend('Rusak Ringan', const Color(0xFFFF9800)),
                _buildLegend('Rusak Berat', const Color(0xFFF44336)),
                _buildLegend('Mati', const Color(0xFF9E9E9E)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}