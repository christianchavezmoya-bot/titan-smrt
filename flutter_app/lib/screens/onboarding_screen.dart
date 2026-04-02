import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_controller.dart';
import '../services/profile_service.dart';
import '../services/settings_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _days = TextEditingController(text: '3');
  final _injury = TextEditingController();
  String _sex = 'unspecified';
  String _goal = 'strength';
  String _level = 'beginner';
  String _equipment = 'full_gym';

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _days.dispose();
    _injury.dispose();
    super.dispose();
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
      // AuthGate rebuilds automatically when profile notifies listeners
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile.')),
      );
    }
  }

  Future<void> _skip() async {
    final controller = context.read<ProfileController>();
    final profile = controller.profile;
    if (profile == null) return;
    // Save minimal profile so isComplete passes and AuthGate routes to AppScaffold
    final updated = UserProfile(
      userId: profile.userId,
      goalType: 'strength',
      experienceLevel: 'beginner',
      equipmentAccess: 'full_gym',
      trainingDaysPerWeek: 3,
    );
    await controller.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your profile'),
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (_step < 2) {
            setState(() => _step += 1);
          } else {
            _save();
          }
        },
        onStepCancel: _step == 0 ? null : () => setState(() => _step -= 1),
        steps: [
          Step(
            title: const Text('Basics'),
            isActive: _step >= 0,
            content: Column(
              children: [
                TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _sex,
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
              ],
            ),
          ),
          Step(
            title: const Text('Goals'),
            isActive: _step >= 1,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _goal,
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
                  initialValue: _level,
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
                  initialValue: _equipment,
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
              ],
            ),
          ),
          Step(
            title: const Text('Notes'),
            isActive: _step >= 2,
            content: Column(
              children: [
                TextField(
                  controller: _injury,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Injury limitations (optional)'),
                ),
                const SizedBox(height: 8),
                const Text('You can edit these later in Settings.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
