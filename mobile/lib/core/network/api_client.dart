import 'dart:async';

import 'package:dio/dio.dart';

import '../config/server_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Dio wrapper: bearer auth, transparent single-flight token refresh, error normalization.
class ApiClient {
  ApiClient(this._tokens, {String? baseUrl})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? ServerConfig.current,
          connectTimeout: connectTimeout,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          contentType: 'application/json',
        )) {
    _refreshDio = Dio(dio.options.copyWith());
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  /// Short timeouts: an unreachable server must surface as an offline error, never a hang.
  static const connectTimeout = Duration(seconds: 8);

  final TokenStorage _tokens;
  final Dio dio;

  String get baseUrl => dio.options.baseUrl;
  set baseUrl(String v) {
    dio.options.baseUrl = v;
    _refreshDio.options.baseUrl = v;
  }
  late final Dio _refreshDio;
  Future<bool>? _refreshing;

  /// Called when the session can no longer be refreshed.
  void Function()? onSessionExpired;

  /// Called after tokens rotate (so the socket can reconnect with the new token).
  void Function(String accessToken)? onTokensRefreshed;

  void _onRequest(RequestOptions o, RequestInterceptorHandler h) {
    final t = _tokens.accessToken;
    if (t != null && o.extra['noAuth'] != true) o.headers['Authorization'] = 'Bearer $t';
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final req = e.requestOptions;
    final is401 = e.response?.statusCode == 401;
    if (!is401 || req.extra['noAuth'] == true || req.extra['retried'] == true || !_tokens.hasSession) {
      return h.next(e);
    }
    final ok = await refreshTokens();
    if (!ok) {
      onSessionExpired?.call();
      return h.next(e);
    }
    try {
      req.extra['retried'] = true;
      req.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
      h.resolve(await dio.fetch(req));
    } on DioException catch (err) {
      h.next(err);
    }
  }

  /// Single-flight refresh shared by HTTP and socket layers.
  Future<bool> refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final rt = _tokens.refreshToken;
    if (rt == null) return false;
    try {
      final r = await _refreshDio.post('/auth/refresh', data: {'refreshToken': rt});
      final data = r.data as Map;
      await _tokens.save(data['accessToken'] as String, data['refreshToken'] as String);
      onTokensRefreshed?.call(data['accessToken'] as String);
      return true;
    } on DioException catch (e) {
      // Only drop the session when the server actively rejected the token.
      if (e.response?.statusCode == 401) await _tokens.clear();
      return false;
    }
  }

  /// Hard upper bound for any non-upload call, independent of socket-level timeouts
  /// (which a captive portal / half-open NAT / VPN can defeat). Cancels the request.
  Duration requestDeadline = const Duration(seconds: 15);

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap((c) => dio.get<T>(path, queryParameters: query, cancelToken: c));
  Future<T> post<T>(String path, {Object? data, bool auth = true}) =>
      _wrap((c) => dio.post<T>(path, data: data ?? {}, options: Options(extra: {'noAuth': !auth}), cancelToken: c));
  Future<T> put<T>(String path, {Object? data}) => _wrap((c) => dio.put<T>(path, data: data ?? {}, cancelToken: c));
  Future<T> patch<T>(String path, {Object? data}) => _wrap((c) => dio.patch<T>(path, data: data ?? {}, cancelToken: c));
  Future<T> upload<T>(String path, FormData form, {void Function(double)? onProgress}) => _wrap(deadline: const Duration(minutes: 3), (c) => dio.post<T>(
        path,
        data: form,
        options: Options(contentType: 'multipart/form-data', sendTimeout: const Duration(minutes: 2), receiveTimeout: const Duration(minutes: 2)),
        onSendProgress: onProgress == null ? null : (s, t) => t > 0 ? onProgress(s / t) : null,
        cancelToken: c,
      ));
  Future<T> delete<T>(String path) => _wrap((c) => dio.delete<T>(path, cancelToken: c));

  /// Every call completes within [deadline] with data or an [ApiException] — never hangs, never
  /// leaks a non-API error type to the UI.
  Future<T> _wrap<T>(Future<Response<T>> Function(CancelToken) call, {Duration? deadline}) async {
    final cancel = CancelToken();
    try {
      final r = await call(cancel).timeout(deadline ?? requestDeadline);
      final data = r.data;
      if (data is! T) throw ApiException('BAD_RESPONSE', 'Unexpected server response', status: r.statusCode);
      return data;
    } on TimeoutException {
      cancel.cancel('deadline');
      throw ApiException('NETWORK', 'Request timed out');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('UNKNOWN', '$e');
    }
  }
}
