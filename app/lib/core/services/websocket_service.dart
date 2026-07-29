import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  Function(Map<String, dynamic>)? _onDataReceived;

  bool get isConnected => _isConnected;

  void connect({required Function(Map<String, dynamic>) onDataReceived}) {
    _onDataReceived = onDataReceived;
    _initWebSocket();
  }

  void _initWebSocket() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final wsUri = Uri.parse('${ApiConstants.wsUrl}?userId=$uid');
      _channel = WebSocketChannel.connect(wsUri);
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            if (_onDataReceived != null) {
              _onDataReceived!(data);
            }
          } catch (_) {}
        },
        onError: (err) {
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _onDataReceived != null) {
        _initWebSocket();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _onDataReceived = null;
  }
}
