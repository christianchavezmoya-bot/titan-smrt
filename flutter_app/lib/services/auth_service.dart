import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService(this.baseUrl);

  final String baseUrl;

  Future<String?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['token'] as String?;
  }

  Future<String?> register(String email, String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'username': username, 'password': password}),
    );
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['token'] as String?;
  }
}
