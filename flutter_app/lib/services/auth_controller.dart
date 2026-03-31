import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;

  bool isReady = false;
  String? token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    if (token != null && _isTokenExpired(token!)) {
      token = null;
      await prefs.remove('auth_token');
    }
    isReady = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final result = await _service.login(email, password);
      if (result != null) {
        token = result;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token!);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> register(String email, String username, String password) async {
    try {
      final result = await _service.register(email, username, password);
      if (result != null) {
        token = result;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token!);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  bool _isTokenExpired(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return false;
    final payload = base64Url.normalize(parts[1]);
    try {
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'];
      if (exp is int) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return DateTime.now().isAfter(expiry);
      }
    } catch (_) {}
    return false;
  }
}
