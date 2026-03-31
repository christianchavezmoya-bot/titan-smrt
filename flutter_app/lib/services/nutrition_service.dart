import 'dart:convert';
import 'api_client.dart';

class NutritionLog {
  NutritionLog({
    required this.date,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.calories,
  });

  final String date;
  final double protein;
  final double carbs;
  final double fats;
  final double calories;

  factory NutritionLog.fromJson(Map<String, dynamic> json) {
    return NutritionLog(
      date: json['date'] as String,
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fats: (json['fats'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
    );
  }
}

class NutritionSummary {
  NutritionSummary({
    required this.date,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.calories,
    required this.trainingVolume7d,
    required this.suggestion,
  });

  final String date;
  final double protein;
  final double carbs;
  final double fats;
  final double calories;
  final double trainingVolume7d;
  final String suggestion;

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    return NutritionSummary(
      date: json['date'] as String,
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fats: (json['fats'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      trainingVolume7d: (json['training_volume_7d'] as num).toDouble(),
      suggestion: json['suggestion'] as String,
    );
  }
}

class NutritionWeekly {
  NutritionWeekly({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.totalCalories,
    required this.averageCalories,
  });

  final String startDate;
  final String endDate;
  final List<NutritionLog> days;
  final double totalCalories;
  final double averageCalories;

  factory NutritionWeekly.fromJson(Map<String, dynamic> json) {
    final days = (json['days'] as List<dynamic>)
        .map((e) => NutritionLog.fromJson(e as Map<String, dynamic>))
        .toList();
    return NutritionWeekly(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      days: days,
      totalCalories: (json['total_calories'] as num).toDouble(),
      averageCalories: (json['average_calories'] as num).toDouble(),
    );
  }
}

class NutritionService {
  NutritionService(this._client);

  final ApiClient _client;

  Future<NutritionLog?> log(double protein, double carbs, double fats) async {
    final response = await _client.postJson(
      '/v1/nutrition/log',
      {'protein': protein, 'carbs': carbs, 'fats': fats},
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return NutritionLog.fromJson(data);
  }

  Future<NutritionSummary?> summary() async {
    final response = await _client.getJson('/v1/nutrition/summary');
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return NutritionSummary.fromJson(data);
  }

  Future<NutritionWeekly?> weekly() async {
    final response = await _client.getJson('/v1/nutrition/weekly');
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return NutritionWeekly.fromJson(data);
  }
}
