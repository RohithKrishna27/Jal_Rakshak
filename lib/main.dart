
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/app/app.dart';
import 'package:priject_jalrakshak/firebase_options.dart';
import 'package:priject_jalrakshak/services/http_server_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start local HTTP server for serving CesiumJS globe
  await HttpServerService.startServer();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const App());
}
