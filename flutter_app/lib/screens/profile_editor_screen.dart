import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_controller.dart';
import '../services/profile_service.dart';
import '../services/settings_controller.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _days = TextEditingController();
  final _injury = TextEditingController();
  String _sex = 'unspecified';
  String _goal = 'strength';
  String _level = 'beginner';
  String _equipment = 'full_gym';
  bool _loaded = false;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _days.dispose();
    _injury.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final profile = context.read<ProfileController>().profile;
    if (profile == null) return;
    _age.text = profile.age?.toString() ?? '';
    _height.text = profile.heightCm?.toString() ?? '';
    _weight.text = profile.weightKg?.toString() ?? '';
    _days.text = profile.trainingDaysPerWeek?.toString() ?? '';
    _injury.text = profile.injuryNotes ?? '';
    _sex = profile.sex ?? 'unspecified';
    _goal = profile.goalType ?? 'strength';
    _level = profile.experienceLevel ?? 'beginner';
    _equipment = profile.equipmentAccess ?? 'full_gym';
    _loaded = true;
  }

  Future<void> _save() async {
    final controller = context.read<ProfileController>();
    final profile = controller.profile;
    if (profile == null) return;
    final updated = UserProfile(
      userId: profile.userId,
      age: int.tryParse(_age.text),
      sex: _sex == 'unspecified' ? null : _sex,
      heightCm: double.tryParse(_height.text),
      weightKg: double.tryParse(_weight.text),
      goalType: _goal,
      experienceLevel: _level,
      equipmentAccess: _equipment,
      trainingDaysPerWeek: int.tryParse(_days.text),
      injuryNotes: _injury.text.isEmpty ? null : _injury.text,
    );
    final ok = await controller.save(updated);
    if (!mounted) return;
    if (ok) {
      final settings = context.read<SettingsController>();
      await settings.updateGoalType(_goal);
      await settings.updateGoalLevel(_level);
      await settings.updateEquipmentAccess(_equipment);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _sex,
            decoration: const InputDecoration(labelText: 'Sex (optional)'),
            items: const [
              DropdownMenuItem(value: 'unspecified', child: Text('Prefer not to say')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
            ],
            onChanged: (value) => setState(() => _sex = value ?? _sex),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _height,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Height (cm)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weight,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _goal,
            decoration: const InputDecoration(labelText: 'Primary goal'),
            items: const [
              DropdownMenuItem(value: 'strength', child: Text('Strength')),
              DropdownMenuItem(value: 'hypertrophy', child: Text('Hypertrophy')),
              DropdownMenuItem(value: 'fat_loss', child: Text('Fat loss')),
              DropdownMenuItem(value: 'endurance', child: Text('Endurance')),
              DropdownMenuItem(value: 'recomp', child: Text('Recomposition')),
            ],
            onChanged: (value) => setState(() => _goal = value ?? _goal),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _level,
            decoration: const InputDecoration(labelText: 'Experience level'),
            items: const [
              DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
              DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
              DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
            ],
            onChanged: (value) => setState(() => _level = value ?? _level),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _equipment,
            decoration: const InputDecoration(labelText: 'Equipment access'),
            items: const [
              DropdownMenuItem(value: 'full_gym', child: Text('Full gym')),
              DropdownMenuItem(value: 'home_minimal', child: Text('Home minimal')),
              DropdownMenuItem(value: 'bodyweight', child: Text('Bodyweight only')),
            ],
            onChanged: (value) => setState(() => _equipment = value ?? _equipment),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _days,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Training days / week'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _injury,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Injury notes'),
          ),
        ],
      ),
    );
  }
}
