import 'dart:convert';

import '../api/api_client.dart';

class AuthApiClient {
  AuthApiClient(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginResponse> login({
    required String username,
    required String password,
    required String pcId,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: <String, dynamic>{
        'username': username,
        'password': password,
        'pcId': pcId,
      },
    );
    final Map<String, dynamic> json = response.data ?? <String, dynamic>{};
    return LoginResponse.fromJson(json);
  }
}

class LoginResponse {
  LoginResponse({
    required this.token,
    required this.refreshToken,
    required this.tenant,
    required this.user,
    required this.balance,
    required this.roles,
  });

  final String token;
  final String refreshToken;
  final Map<String, dynamic> tenant;
  final Map<String, dynamic> user;
  final double? balance;
  final List<String> roles;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data =
        (json['data'] as Map<String, dynamic>?) ?? json;
    final Map<String, dynamic> userData =
        data['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final dynamic rolesRaw = userData['roles'];
    final List<String> roles = switch (rolesRaw) {
      List<dynamic> list => list.map((dynamic item) => item.toString()).toList(),
      String single => <String>[single],
      _ => <String>[],
    };
    return LoginResponse(
      token: data['token'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      tenant: data['tenant'] as Map<String, dynamic>? ?? <String, dynamic>{},
      user: userData,
      balance: (data['balance'] as num?)?.toDouble(),
      roles: roles,
    );
  }

  @override
  String toString() => jsonEncode(<String, dynamic>{
        'token': token,
        'refreshToken': refreshToken,
        'tenant': tenant,
        'user': user,
        'balance': balance,
        'roles': roles,
      });
}
