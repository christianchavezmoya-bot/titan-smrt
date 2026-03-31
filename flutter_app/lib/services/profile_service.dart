import 'dart:convert';
import 'api_client.dart';

class UserProfile {
  UserProfile({
    required this.userId,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.goalType,
    this.experienceLevel,
    this.equipmentAccess,
    this.trainingDaysPerWeek,
    this.injuryNotes,
  });

  final String userId;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final String? goalType;
  final String? experienceLevel;
  final String? equipmentAccess;
  final int? trainingDaysPerWeek;
  final String? injuryNotes;

  bool get isComplete =>
      goalType != null &&
      experienceLevel != null &&
      equipmentAccess != null &&
      trainingDaysPerWeek != null;

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'sex': sex,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal_type': goalType,
      'experience_level': experienceLevel,
      'equipment_access': equipmentAccess,
      'training_days_per_week': trainingDaysPerWeek,
      'injury_notes': injuryNotes,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      age: json['age'] as int?,
      sex: json['sex'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      goalType: json['goal_type'] as String?,
      experienceLevel: json['experience_level'] as String?,
      equipmentAccess: json['equipment_access'] as String?,
      trainingDaysPerWeek: json['training_days_per_week'] as int?,
      injuryNotes: json['injury_notes'] as String?,
    );
  }
}

class ProfileService {
  ProfileService(this._client);

  final ApiClient _client;

  Future<UserProfile?> fetchProfile() async {
    final response = await _client
        .getJson('/v1/profile')
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile?> updateProfile(UserProfile profile) async {
    final response = await _client
        .putJson('/v1/profile', profile.toJson())
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  String? currentUserId() {
    final token = _client.token;
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    try {
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}
