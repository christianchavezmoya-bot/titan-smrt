import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class AppError implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  AppError({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => message;
}

class ErrorHandler {
  static AppError handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout) {
      return AppError(
        message: 'Connection timeout. Please check your internet connection.',
        statusCode: 408,
      );
    }

    if (error.type == DioExceptionType.receiveTimeout) {
      return AppError(
        message: 'Server timeout. Please try again.',
        statusCode: 408,
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return AppError(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
      );
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode!;
      final data = error.response!.data;

      switch (statusCode) {
        case 400:
          return AppError(
            message: data['error'] ?? 'Bad request',
            statusCode: statusCode,
            details: data,
          );
        case 401:
          return AppError(
            message: 'Unauthorized. Please log in again.',
            statusCode: statusCode,
          );
        case 403:
          return AppError(
            message: 'Access forbidden',
            statusCode: statusCode,
          );
        case 404:
          return AppError(
            message: 'Resource not found',
            statusCode: statusCode,
          );
        case 409:
          return AppError(
            message: data['error'] ?? 'Conflict with existing data',
            statusCode: statusCode,
            details: data,
          );
        case 500:
          return AppError(
            message: 'Server error. Please try again later.',
            statusCode: statusCode,
          );
        default:
          return AppError(
            message: data['error'] ?? 'An error occurred',
            statusCode: statusCode,
            details: data,
          );
      }
    }

    return AppError(
      message: 'An unexpected error occurred',
      statusCode: null,
      details: error.toString(),
    );
  }

  static void showError(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
