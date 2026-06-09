// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void saveWebCalibration(String serialized) {
  try {
    html.window.localStorage['map_calibrations_cache'] = serialized;
  } catch (_) {}
}

String? loadWebCalibration() {
  try {
    return html.window.localStorage['map_calibrations_cache'];
  } catch (_) {
    return null;
  }
}
