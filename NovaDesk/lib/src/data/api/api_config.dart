class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.wsBaseUrl,
  });

  /// REST API 基础地址，例如 `http://120.26.30.221`。
  final String baseUrl;

  /// WebSocket 基础地址，例如 `ws://120.26.30.221`。
  final String wsBaseUrl;

  static ApiConfig fromBaseUrl(String baseUrl) {
    final Uri uri = Uri.parse(baseUrl);
    final String scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
    final String host = uri.hasAuthority ? uri.authority : uri.path;
    final String normalizedRest = Uri.parse('$scheme://$host').toString();
    final String wsScheme = scheme == 'https' ? 'wss' : 'ws';
    final String normalizedWs = Uri.parse('$wsScheme://$host').toString();
    return ApiConfig(baseUrl: normalizedRest, wsBaseUrl: normalizedWs);
  }
}
