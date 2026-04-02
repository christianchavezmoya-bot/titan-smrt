import 'package:flutter/material.dart';
import 'app.dart';
import 'services/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/local_store.dart';
import 'services/settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _bootstrap();
}

Future<void> _bootstrap() async {
  final store = await LocalStoreSqlite.open();
  final authController = AuthController(AuthService('http://10.7.15.96:8000'));
  await authController.init();
  final settingsController = SettingsController();
  await settingsController.init();
  runApp(
    TitanApp(
      store: store,
      authController: authController,
      settingsController: settingsController,
    ),
  );
}
