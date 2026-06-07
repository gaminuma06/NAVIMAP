// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;

bool _lastKnownOnlineState = true;
bool _isChecking = false;

bool isWebOnline() {
  _verifyWebOnlineInBackground();
  return _lastKnownOnlineState;
}

void _verifyWebOnlineInBackground() async {
  if (_isChecking) return;
  _isChecking = true;
  try {
    final browserOnline = html.window.navigator.onLine;
    if (browserOnline == true) {
      _lastKnownOnlineState = true;
      _isChecking = false;
      return;
    }

    // Si el navegador reporta offline, hacemos una verificación real rápida
    // a un endpoint confiable y compatible con CORS (Cloudflare trace)
    final response = await http
        .head(Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'))
        .timeout(const Duration(milliseconds: 1500));
    _lastKnownOnlineState = response.statusCode == 200;
  } catch (_) {
    _lastKnownOnlineState = false;
  } finally {
    _isChecking = false;
  }
}
