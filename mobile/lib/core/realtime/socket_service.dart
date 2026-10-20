import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/server_config.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/token_storage.dart';

enum SocketStatus { disconnected, connecting, connected }

class SocketEvent {
  const SocketEvent(this.name, this.data);
  final String name;
  final Map<String, dynamic> data;
}

/// Single authenticated Socket.IO connection for matching + chat.
class SocketService {
  SocketService(this._tokens, this._api);

  final TokenStorage _tokens;
  final ApiClient _api;
  io.Socket? _socket;
  final _events = StreamController<SocketEvent>.broadcast();
  final status = ValueNotifier<SocketStatus>(SocketStatus.disconnected);

  static const _serverEvents = [
    'match:found', 'match:liked', 'match:mutual', 'match:ended',
    'soul:message', 'soul:typing',
    'chat:message', 'chat:typing', 'chat:read', 'chat:pending', 'chat:delivered',
    'presence:update', 'friends:changed',
    'call:incoming', 'call:accepted', 'call:ended',
  ];

  Stream<SocketEvent> get events => _events.stream;
  Stream<Map<String, dynamic>> on(String name) => events.where((e) => e.name == name).map((e) => e.data);

  void connect() {
    if (_socket != null) return;
    status.value = SocketStatus.connecting;
    final s = io.io(
      ServerConfig.current,
      io.OptionBuilder()
          .setTimeout(8000)
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          // Re-evaluated on every (re)connect so refreshed tokens are picked up.
          .setAuthFn((cb) => cb({'token': _tokens.accessToken ?? ''}))
          .build(),
    );
    s.on('ready', (_) => status.value = SocketStatus.connected);
    s.onDisconnect((_) => status.value = SocketStatus.connecting);
    s.onConnectError((_) => status.value = SocketStatus.connecting);
    s.on('auth_error', (_) async {
      // Access token expired: refresh then reconnect.
      if (await _api.refreshTokens()) {
        s.connect();
      }
    });
    for (final name in _serverEvents) {
      s.on(name, (data) {
        if (data is Map) _events.add(SocketEvent(name, Map<String, dynamic>.from(data)));
      });
    }
    s.connect();
    _socket = s;
  }

  /// Server address changed: drop the old socket and reconnect to the new one if we were connected.
  void switchServer() {
    if (_socket == null) return;
    disconnect();
    connect();
  }

  void reconnect() {
    final s = _socket;
    if (s == null) return connect();
    s.disconnect();
    s.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    status.value = SocketStatus.disconnected;
  }

  /// Emits and awaits the server ack `{ok, data}` / `{ok:false, code, message}`.
  Future<T> request<T>(String event, [Map<String, dynamic>? payload]) async {
    final s = _socket;
    if (s == null || !s.connected) throw ApiException('NETWORK', 'Not connected');
    final res = await s
        .emitWithAckAsync(event, payload ?? <String, dynamic>{})
        .timeout(const Duration(seconds: 10), onTimeout: () => throw ApiException('NETWORK', 'Timeout'));
    if (res is Map && res['ok'] == true) return res['data'] as T;
    if (res is Map) throw ApiException.fromAck(res);
    throw ApiException('UNKNOWN', 'Bad ack');
  }

  /// Fire-and-forget (typing indicators etc.).
  void send(String event, Map<String, dynamic> payload) {
    final s = _socket;
    if (s != null && s.connected) s.emitWithAck(event, payload, ack: (_) {});
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}
