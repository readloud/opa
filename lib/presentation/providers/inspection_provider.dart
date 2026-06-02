import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opa_app/data/repositories/inspection_repository_impl.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  return InspectionRepository();
});