import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'navigation/app_scaffold.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_client.dart';
import 'services/auth_controller.dart';
import 'services/local_store.dart';
import 'services/profile_controller.dart';
import 'services/profile_service.dart';
import 'services/settings_controller.dart';
import 'services/sync_controller.dart';
import 'theme.dart';

class TitanApp extends StatelessWidget {
  const TitanApp({
    super.key,
    required this.store,
    required this.authController,
    required this.settingsController,
  });

  final LocalStoreSqlite store;
  final AuthController authController;
  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStoreSqlite>.value(value: store),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ProxyProvider<AuthController, ApiClient>(
          update: (_, auth, previous) {
            final client = previous ?? ApiClient(baseUrl: 'http://192.168.1.103:8000');
            client.token = auth.token;
            return client;
          },
        ),
        ChangeNotifierProvider<SettingsController>.value(value: settingsController),
        ChangeNotifierProxyProvider<ApiClient, ProfileController>(
          create: (context) => ProfileController(ProfileService(context.read<ApiClient>())),
          update: (context, client, previous) {
            if (previous == null) {
              return ProfileController(ProfileService(client));
            }
            previous.updateService(ProfileService(client));
            return previous;
          },
        ),
        ChangeNotifierProvider(
          create: (context) => SyncController(
            apiClient: context.read<ApiClient>(),
            store: context.read<LocalStoreSqlite>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Titan',
        theme: buildTitanTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = context.watch<ProfileController>();
    if (!auth.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.token == null) {
      profile.clear();
      return const AuthScreen();
    }
    if (profile.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!profile.isReady) {
      profile.load();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile.profile == null || !(profile.profile?.isComplete ?? false)) {
      return const OnboardingScreen();
    }
    return const AppScaffold();
  }
}

