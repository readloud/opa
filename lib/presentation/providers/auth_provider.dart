import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opa_app/data/remote/repositories/auth_repository.dart';
import 'package:opa_app/domain/entities/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userProvider = StateProvider<User?>((ref) => null);

final authStateProvider = FutureProvider<User?>((ref) async {
  final authRepo = ref.read(authRepositoryProvider);
  final isLoggedIn = await authRepo.isLoggedIn();
  if (!isLoggedIn) return null;
  return await authRepo.getCurrentUser();
});