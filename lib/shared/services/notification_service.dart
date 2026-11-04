library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channel = EventChannel('com.deva.assistant/notifications');

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notifications => _controller.stream;

  StreamSubscription? _subscription;

  void initialize() {
    if (_subscription != null) return;
    _subscription = _channel.receiveBroadcastStream().listen(
      (event) {
        try {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(event as Map);
          debugPrint('[NotificationService] Received: $data');
          _controller.add(data);
        } catch (e) {
          debugPrint('[NotificationService] Error parsing event: $e');
        }
      },
      onError: (e) => debugPrint('[NotificationService] Channel error: $e'),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
