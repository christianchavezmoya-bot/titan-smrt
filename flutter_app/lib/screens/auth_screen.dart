import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_controller.dart';
import '../services/api_client.dart';
import '../widgets/staggered_fade_in.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  bool _isRegister = false;
  bool _isBusy = false;
  bool _isTesting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    bool ok;
    if (_isRegister) {
      ok = await auth.register(_email.text, _username.text, _password.text);
    } else {
      ok = await auth.login(_email.text, _password.text);
    }
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (!ok) {
        _error = 'Unable to authenticate. Check your credentials.';
      }
    });
  }

  Future<void> _testApi() async {
    setState(() {
      _isTesting = true;
    });
    final client = context.read<ApiClient>();
    try {
      final response = await client.getJson('/v1/health');
      if (!mounted) return;
      final ok = response.statusCode == 200;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'API reachable.' : 'API error: ${response.statusCode}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF151515), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Center(
                    child: StaggeredFadeIn(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Titan',
                                    style: Theme.of(context).textTheme.headlineLarge),
                                const SizedBox(height: 6),
                                const Text('The AI that trains with you.'),
                                const SizedBox(height: 16),
                                Text(
                                  _isRegister ? 'Create your account' : 'Welcome back',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _email,
                                  decoration: const InputDecoration(labelText: 'Email'),
                                ),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isRegister
                                      ? Column(
                                          key: const ValueKey('register'),
                                          children: [
                                            TextField(
                                              controller: _username,
                                              decoration:
                                                  const InputDecoration(labelText: 'Username'),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                TextField(
                                  controller: _password,
                                  obscureText: true,
                                  decoration: const InputDecoration(labelText: 'Password'),
                                ),
                                const SizedBox(height: 16),
                                if (_error != null) ...[
                                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                                  const SizedBox(height: 8),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _isBusy ? null : _submit,
                                    child: Text(_isRegister ? 'Create account' : 'Sign in'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isBusy
                                      ? null
                                      : () => setState(() => _isRegister = !_isRegister),
                                  child: Text(_isRegister
                                      ? 'Already have an account? Sign in'
                                      : 'Need an account? Register'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _isTesting ? null : _testApi,
                                  child: _isTesting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Test API'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
