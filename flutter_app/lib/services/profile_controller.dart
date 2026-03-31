import 'package:flutter/material.dart';
import 'profile_service.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._service);

  ProfileService _service;
  bool isReady = false;
  bool isLoading = false;
  UserProfile? profile;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      profile = await _service.fetchProfile();
      profile ??= UserProfile(userId: _service.currentUserId() ?? 'unknown');
    } finally {
      isLoading = false;
      isReady = true;
      notifyListeners();
    }
  }

  Future<bool> save(UserProfile updated) async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _service.updateProfile(updated);
      if (result != null) {
        profile = result;
        return true;
      }
      return false;
    } finally {
      isLoading = false;
      isReady = true;
      notifyListeners();
    }
  }

  void clear() {
    profile = null;
    isReady = false;
    isLoading = false;
    notifyListeners();
  }

  void updateService(ProfileService service) {
    _service = service;
  }
}
