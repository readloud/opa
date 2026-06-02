import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opa_app/services/analytics_service.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

final analyticsProvider = StateNotifierProvider<AnalyticsNotifier, DashboardState>((ref) {
  return AnalyticsNotifier(ref.read(analyticsServiceProvider));
});

final realtimeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(analyticsServiceProvider);
  return await service.getRealtimeStats();
});

class DashboardState {
  final bool isLoading;
  final double? totalProduction;
  final double? averagePerDay;
  final int? totalRecords;
  final int? totalInspections;
  final double? healthyPercentage;
  final int? totalFertilizations;
  final double? totalFertilizerKg;
  final int? completedTasks;
  final int? pendingTasks;
  final int? totalTasks;
  final double? completionRate;
  final double? productionTrend;
  final List<Map<String, dynamic>>? productionData;
  final Map<String, int>? conditionCount;
  final List<Map<String, dynamic>>? topBlocks;
  final List<Map<String, dynamic>>? monthlyTrend;
  final Map<String, int>? taskByType;

  DashboardState({
    this.isLoading = true,
    this.totalProduction,
    this.averagePerDay,
    this.totalRecords,
    this.totalInspections,
    this.healthyPercentage,
    this.totalFertilizations,
    this.totalFertilizerKg,
    this.completedTasks,
    this.pendingTasks,
    this.totalTasks,
    this.completionRate,
    this.productionTrend,
    this.productionData,
    this.conditionCount,
    this.topBlocks,
    this.monthlyTrend,
    this.taskByType,
  });

  DashboardState copyWith({
    bool? isLoading,
    double? totalProduction,
    double? averagePerDay,
    int? totalRecords,
    int? totalInspections,
    double? healthyPercentage,
    int? totalFertilizations,
    double? totalFertilizerKg,
    int? completedTasks,
    int? pendingTasks,
    int? totalTasks,
    double? completionRate,
    double? productionTrend,
    List<Map<String, dynamic>>? productionData,
    Map<String, int>? conditionCount,
    List<Map<String, dynamic>>? topBlocks,
    List<Map<String, dynamic>>? monthlyTrend,
    Map<String, int>? taskByType,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      totalProduction: totalProduction ?? this.totalProduction,
      averagePerDay: averagePerDay ?? this.averagePerDay,
      totalRecords: totalRecords ?? this.totalRecords,
      totalInspections: totalInspections ?? this.totalInspections,
      healthyPercentage: healthyPercentage ?? this.healthyPercentage,
      totalFertilizations: totalFertilizations ?? this.totalFertilizations,
      totalFertilizerKg: totalFertilizerKg ?? this.totalFertilizerKg,
      completedTasks: completedTasks ?? this.completedTasks,
      pendingTasks: pendingTasks ?? this.pendingTasks,
      totalTasks: totalTasks ?? this.totalTasks,
      completionRate: completionRate ?? this.completionRate,
      productionTrend: productionTrend ?? this.productionTrend,
      productionData: productionData ?? this.productionData,
      conditionCount: conditionCount ?? this.conditionCount,
      topBlocks: topBlocks ?? this.topBlocks,
      monthlyTrend: monthlyTrend ?? this.monthlyTrend,
      taskByType: taskByType ?? this.taskByType,
    );
  }
}

class AnalyticsNotifier extends StateNotifier<DashboardState> {
  final AnalyticsService _service;

  AnalyticsNotifier(this._service) : super(DashboardState());

  Future<void> loadDashboardData(DateTime startDate, DateTime endDate) async {
    state = state.copyWith(isLoading: true);

    try {
      final data = await _service.getDashboardStats(startDate, endDate);
      
      state = DashboardState(
        isLoading: false,
        totalProduction: data['summary']['totalProduction'],
        averagePerDay: data['summary']['averageProductionPerDay'],
        totalRecords: data['productionStats']['totalRecords'],
        totalInspections: data['summary']['totalInspections'],
        healthyPercentage: data['summary']['healthyPercentage'],
        totalFertilizations: data['summary']['totalFertilizations'],
        totalFertilizerKg: data['summary']['totalFertilizerKg'],
        completedTasks: data['summary']['completedTasks'],
        pendingTasks: data['summary']['pendingTasks'],
        totalTasks: data['taskStats']['total'],
        completionRate: data['taskStats']['completionRate'],
        productionData: List<Map<String, dynamic>>.from(data['productionStats']['dailyData']),
        conditionCount: Map<String, int>.from(data['inspectionStats']['conditionCount']),
        topBlocks: List<Map<String, dynamic>>.from(data['topBlocks']),
        monthlyTrend: List<Map<String, dynamic>>.from(data['monthlyTrend']),
        taskByType: Map<String, int>.from(data['taskStats']['byType']),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}