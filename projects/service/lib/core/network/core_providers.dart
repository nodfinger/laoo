import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_service.dart';
import '../auth/auth_storage.dart';
import '../network/http_service.dart';

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

final httpServiceProvider = Provider<HttpService>((ref) {
  final service = HttpService(authStorage: ref.watch(authStorageProvider));

  ref.onDispose(service.dispose);
  return service;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(httpService: ref.watch(httpServiceProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    apiClient: ref.watch(apiClientProvider),
    authStorage: ref.watch(authStorageProvider),
  ),
);
