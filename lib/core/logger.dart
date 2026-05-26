import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Simple lightweight logger wrapper using `dart:developer`.
/// - `logDebug` writes only in debug mode.
/// - `logInfo` and `logError` always write.
const _loggerName = 'buzhor_courier';

void logDebug(String message) {
  if (kDebugMode) {
    developer.log(message, name: _loggerName, level: 700);
  }
}

void logInfo(String message) {
  developer.log(message, name: _loggerName, level: 800);
}

void logError(String message, {Object? error, StackTrace? stack}) {
  developer.log(message, name: _loggerName, level: 1000, error: error, stackTrace: stack);
}
