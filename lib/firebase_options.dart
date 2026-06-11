import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: "AIzaSyB5h5Dv_8cWPoPPlPoZTeEzMYjBlB-iwpQ",
        authDomain: "navimap-15d79.firebaseapp.com",
        projectId: "navimap-15d79",
        storageBucket: "navimap-15d79.firebasestorage.app",
        messagingSenderId: "776067923020",
        appId: "1:776067923020:web:0bac2215e09c77ca9cc8e9",
      );
    }
    // En plataformas nativas (Android), se retorna null para que Firebase
    // lea automáticamente el archivo 'google-services.json'.
    return null;
  }
}
