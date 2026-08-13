import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Thin wrapper around the `logger` package providing a single, app-wide
/// configured logger. Logging is silenced in release builds by default.
class AppLogger {
  AppLogger({Logger? logger}) : _logger = logger ?? _defaultLogger();

  final Logger _logger;

  static Logger _defaultLogger() {
    return Logger(
      level: kReleaseMode ? Level.warning : Level.debug,
      filter: _AppLogFilter(),
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 6,
        lineLength: 90,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  void t(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _logger.t(message, error: error, stackTrace: stackTrace);

  void d(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  void i(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _logger.i(message, error: error, stackTrace: stackTrace);

  void w(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  void e(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  void f(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _logger.f(message, error: error, stackTrace: stackTrace);

  void close() => _logger.close();
}

/// Filters out all logs in release mode below the warning threshold.
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    return event.level.index >= Level.debug.index;
  }
}
