import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class IntentService {
  static const MethodChannel _channel = MethodChannel('intent_handler');
  static IntentService? _instance;

  // Callback function to handle navigation
  Function(String action, Map<String, dynamic>? extras)? _onIntentReceived;

  IntentService._();

  static IntentService get instance {
    _instance ??= IntentService._();
    return _instance!;
  }

  /// Initialize the intent service and set up the method call handler
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);

    // Check if the app was started with an intent
    await _checkInitialIntent();
  }

  /// Set the callback for when an intent is received
  void setIntentHandler(
      Function(String action, Map<String, dynamic>? extras) handler) {
    _onIntentReceived = handler;
  }

  /// Handle method calls from the Android side
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNewIntent':
        final String action = call.arguments['action'] ?? '';
        final Map<String, dynamic>? extras =
            call.arguments['extras']?.cast<String, dynamic>();
        _onIntentReceived?.call(action, extras);
        break;
      default:
        break;
    }
  }

  /// Check if the app was launched with a specific intent
  Future<void> _checkInitialIntent() async {
    try {
      final Map<dynamic, dynamic>? intentData =
          await _channel.invokeMethod('getInitialIntent');
      if (intentData != null) {
        final String action = intentData['action'] ?? '';
        final Map<String, dynamic>? extras =
            intentData['extras']?.cast<String, dynamic>();
        if (action.isNotEmpty) {
          // Delay the callback to ensure the app is fully initialized
          Future.delayed(const Duration(milliseconds: 500), () {
            _onIntentReceived?.call(action, extras);
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking initial intent: $e');
    }
  }
}
