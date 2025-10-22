import '../../data/clients/auth_api_client.dart';
import '../../data/services/pc_identity_service.dart';

class AuthService {
  AuthService({
    required AuthApiClient authApiClient,
    required PcIdentityService identityService,
  })  : _authApiClient = authApiClient,
        _identityService = identityService;

  final AuthApiClient _authApiClient;
  final PcIdentityService _identityService;

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final identity = await _identityService.ensureLoaded();
    final response = await _authApiClient.login(
      username: username,
      password: password,
      pcId: identity.pcId,
    );
    return response;
  }
}
