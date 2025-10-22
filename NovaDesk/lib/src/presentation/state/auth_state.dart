import 'package:meta/meta.dart';

const Object _noChange = Object();

@immutable
class AuthState {
  const AuthState({
    required this.status,
    this.token,
    this.refreshToken,
    this.errorMessage,
    this.session,
  });

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        token = null,
        refreshToken = null,
        errorMessage = null,
        session = null;

  final AuthStatus status;
  final String? token;
  final String? refreshToken;
  final String? errorMessage;
  final AuthSession? session;

  AuthState copyWith({
    AuthStatus? status,
    Object? token = _noChange,
    Object? refreshToken = _noChange,
    Object? errorMessage = _noChange,
    Object? session = _noChange,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: identical(token, _noChange) ? this.token : token as String?,
      refreshToken:
          identical(refreshToken, _noChange) ? this.refreshToken : refreshToken as String?,
      errorMessage:
          identical(errorMessage, _noChange) ? this.errorMessage : errorMessage as String?,
      session: identical(session, _noChange) ? this.session : session as AuthSession?,
    );
  }
}

enum AuthStatus { unauthenticated, loading, authenticated }

enum UserRole { superAdmin, admin, user, unknown }

@immutable
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.role,
    required this.roles,
    this.username,
    this.displayName,
    this.tenantId,
    this.tenantName,
    this.balance,
  });

  final String userId;
  final UserRole role;
  final List<UserRole> roles;
  final String? username;
  final String? displayName;
  final String? tenantId;
  final String? tenantName;
  final double? balance;
}
