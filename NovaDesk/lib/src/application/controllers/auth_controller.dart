import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';

import '../../application/services/auth_service.dart';
import '../../presentation/state/auth_state.dart';
import '../../data/clients/auth_api_client.dart';
import '../../data/api/api_client.dart';
import '../../bootstrap/bootstrap.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthService authService,
    required ApiClient apiClient,
    required Bootstrap bootstrap,
  })  : _authService = authService,
        _apiClient = apiClient,
        _bootstrap = bootstrap,
        super(const AuthState.unauthenticated());

  final AuthService _authService;
  final ApiClient _apiClient;
  final Bootstrap _bootstrap;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _authService.login(
        username: username,
        password: password,
      );
      if (response.token.isEmpty) {
        throw Exception('登录响应缺少 token');
      }
      _apiClient.updateAuthToken(response.token);
      await _bootstrap.onAuthenticated(token: response.token);
      final AuthSession session = _buildSession(response);
      state = AuthState(
        status: AuthStatus.authenticated,
        token: response.token,
        refreshToken: response.refreshToken,
        session: session,
      );
    } on DioException catch (error) {
      final responseMessage = error.response?.data is Map
          ? (error.response!.data['message']?.toString() ?? '')
          : '';
      final detailed = '[${error.type}] ${responseMessage.isNotEmpty ? responseMessage : error.message}';
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: detailed,
        session: null,
      );
      throw Exception(detailed);
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: error.toString(),
        session: null,
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AuthState.unauthenticated();
    _apiClient.updateAuthToken(null);
    await _bootstrap.onLogout();
  }

  AuthSession _buildSession(LoginResponse response) {
    final String userId = response.user['id']?.toString() ?? '';
    final String? username = response.user['username']?.toString();
    final String? displayName = response.user['name']?.toString();
    final String? tenantId = response.tenant['id']?.toString();
    final String? tenantName = response.tenant['name']?.toString();
    final List<UserRole> roles =
        response.roles.map(_resolveRole).where((UserRole role) => role != UserRole.unknown).toList();
    final UserRole primaryRole = roles.isNotEmpty ? roles.first : UserRole.unknown;
    return AuthSession(
      userId: userId,
      username: username,
      displayName: displayName,
      role: primaryRole,
      roles: roles.isNotEmpty ? roles : <UserRole>[UserRole.unknown],
      tenantId: tenantId,
      tenantName: tenantName,
      balance: response.balance,
    );
  }

  UserRole _resolveRole(String role) {
    return switch (role.toUpperCase()) {
      'SUPER_ADMIN' => UserRole.superAdmin,
      'ADMIN' => UserRole.admin,
      'USER' => UserRole.user,
      _ => UserRole.unknown,
    };
  }
}
