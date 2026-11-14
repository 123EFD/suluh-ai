import 'package:flutter/foundation.dart';

/// Centralized API Configuration for Suluh AI Suite
///
/// Automatically routes network requests based on the compilation environment:
/// - In **Release mode** (`flutter build web` / production deployment): targets the cloud backend.
/// - In **Debug mode** (`flutter run`): targets `http://localhost:8000`.
/// - Can be overridden at build or run time via `--dart-define=API_URL=https://...`
class ApiConfig {
  /// Optional environment override provided at compile time:
  /// e.g. `flutter build web --dart-define=API_URL=https://kasshier-ai-study-suite.hf.space`
  static const String _envUrl = String.fromEnvironment('API_URL');

  /// Production Cloud Backend (Hugging Face Spaces)
  static const String productionUrl = "https://kasshier-ai-study-suite.hf.space";

  /// Local Development Backend
  static const String localUrl = "http://localhost:8000";

  /// The active base URL for API requests
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl.endsWith('/') ? _envUrl.substring(0, _envUrl.length - 1) : _envUrl;
    }
    // In production web build, target the live cloud backend
    if (kReleaseMode) {
      return productionUrl;
    }
    // In local development/debug mode, default to localhost
    return localUrl;
  }
}
