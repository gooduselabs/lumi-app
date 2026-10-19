import 'package:dio/dio.dart';

/// Normalized API error. `code` is the stable server error code (e.g. INVALID_CODE).
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status, this.retryAfter});

  final String code;
  final String message;
  final int? status;
  final int? retryAfter;

  bool get isNetwork => code == 'NETWORK';

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      return ApiException(
        (data['code'] as String?) ?? (e.response?.statusCode == 400 ? 'VALIDATION' : 'HTTP_${e.response?.statusCode}'),
        msg is List ? msg.join('\n') : (msg?.toString() ?? 'Error'),
        status: e.response?.statusCode,
        retryAfter: (data['retryAfter'] as num?)?.toInt(),
      );
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException('NETWORK', 'Network error');
    }
    return ApiException('UNKNOWN', e.message ?? 'Unknown error', status: e.response?.statusCode);
  }

  factory ApiException.fromAck(Map ack) =>
      ApiException((ack['code'] as String?) ?? 'ERROR', (ack['message'] as String?) ?? 'Error');

  @override
  String toString() => 'ApiException($code, $message)';
}
