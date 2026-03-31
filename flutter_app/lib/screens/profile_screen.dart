import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../widgets/staggered_fade_in.dart';
import 'package:provider/provider.dart';
import '../services/local_store.dart';
import '../services/settings_controller.dart';
import 'profile_editor_screen.dart';
import '../services/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<LocalStoreSqlite>();
    return SafeArea(
      child: StaggeredFadeIn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 16),
            const _PlaceholderTile(title: 'Subscription'),
            Card(
              child: ListTile(
                title: const Text('Log out'),
                trailing: const Icon(Icons.logout),
                onTap: () async {
                  await context.read<AuthController>().logout();
                },
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _SettingsScreen()),
                  );
                },
              ),
            ),
            const _PlaceholderTile(title: 'Social Feed'),
            Card(
              child: ListTile(
                title: const Text('Conflict Audit Log'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ConflictAuditScreen(store: store),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  final String title;

  const _PlaceholderTile({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}

class _ConflictAuditScreen extends StatefulWidget {
  const _ConflictAuditScreen({required this.store});

  final LocalStoreSqlite store;

  @override
  State<_ConflictAuditScreen> createState() => _ConflictAuditScreenState();
}

class _ConflictAuditScreenState extends State<_ConflictAuditScreen> {
  bool _onlyDiffs = false;
  bool _onlyLocal = false;
  bool _onlyServer = false;
  final Set<String> _entityFilters = {};
  late Future<List<Map<String, dynamic>>> _auditFuture;
  DateTime? _lastRefreshedAt;

  @override
  void initState() {
    super.initState();
    _auditFuture = widget.store.listConflictAudit();
    _lastRefreshedAt = DateTime.now();
    _loadFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<List<Map<String, dynamic>>>(
          future: _auditFuture,
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            final diffCount = items.where(_hasDiffFromItem).length;
            return Row(
              children: [
                const Text('Conflict Audit Log'),
                const SizedBox(width: 8),
                if (diffCount > 0)
                  Chip(
                    label: Text('$diffCount diffs'),
                  ),
                FutureBuilder<_ExportDefaults>(
                  future: _loadExportDefaults(),
                  builder: (context, defaultsSnap) {
                    final defaults = defaultsSnap.data;
                    if (defaults == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const _ExportDefaultsScreen()),
                          );
                        },
                        child: Chip(
                          label: Text(defaults.formatLabel),
                        ),
                      ),
                    );
                  },
                ),
                if (_lastRefreshedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Tooltip(
                      message: _formatFullDateTime(_lastRefreshedAt!),
                      child: Text(
                        'Updated ${_formatTime(_lastRefreshedAt!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dataset),
            tooltip: 'Copy CSV',
            onPressed: () async {
              HapticFeedback.selectionClick();
              final rows = await _auditFuture;
              final export = _buildAuditExport(
                rows,
                _ExportDefaults(formatLabel: 'CSV', includeSnapshots: false),
              );
              await Clipboard.setData(ClipboardData(text: export.content));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Copy JSON',
            onPressed: () async {
              HapticFeedback.selectionClick();
              final rows = await _auditFuture;
              final export = _buildAuditExport(
                rows,
                _ExportDefaults(formatLabel: 'JSON', includeSnapshots: false),
              );
              await Clipboard.setData(ClipboardData(text: export.content));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON copied')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            tooltip: 'Copy JSON + snapshots',
            onPressed: () async {
              HapticFeedback.selectionClick();
              final rows = await _auditFuture;
              final export = _buildAuditExport(
                rows,
                _ExportDefaults(formatLabel: 'JSON', includeSnapshots: true),
              );
              await Clipboard.setData(ClipboardData(text: export.content));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON + snapshots copied')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Copy with preview',
            onPressed: () async {
              HapticFeedback.selectionClick();
              final rows = await _auditFuture;
              final defaults = await _loadExportDefaults();
              final export = _buildAuditExport(rows, defaults);
              if (!context.mounted) return;
              await _showCopyExportDialog(context, export);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share export',
            onPressed: () async {
              HapticFeedback.selectionClick();
              final rows = await _auditFuture;
              final defaults = await _loadExportDefaults();
              final export = _buildAuditExport(rows, defaults);
              await Share.share(export.content, subject: 'Titan Conflict Audit Log');
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Save to Files',
            onPressed: () async {
              HapticFeedback.selectionClick();
              final rows = await _auditFuture;
              final defaults = await _loadExportDefaults();
              final export = _buildAuditExport(rows, defaults);
              final directory = await getTemporaryDirectory();
              final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
              final file = File('${directory.path}/titan_conflicts_$stamp.${export.extension}');
              await file.writeAsString(export.content);
              await Share.shareXFiles([XFile(file.path)], text: 'Titan Conflict Audit Log');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear audit log',
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await widget.store.clearConflictAudit();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audit log cleared')),
              );
              setState(() {
                _auditFuture = widget.store.listConflictAudit();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _auditFuture = widget.store.listConflictAudit();
                _lastRefreshedAt = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _auditFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load audit log'));
          }
          final allItems = snapshot.data ?? [];
          final items = _applyFilters(allItems);
          final diffCount = allItems.where(_hasDiffFromItem).length;
          final localCount = allItems.where((item) => item['resolution'] == 'local').length;
          final serverCount = allItems.where((item) => item['resolution'] == 'server').length;
          final entities = allItems
              .map((item) => item['entity'] as String? ?? 'unknown')
              .toSet()
              .toList()
            ..sort();
          if (items.isEmpty) {
            return const Center(child: Text('No conflicts yet.'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text('Only diffs ($diffCount)'),
                      selected: _onlyDiffs,
                      onSelected: (value) {
                        setState(() => _onlyDiffs = value);
                        _saveFilters();
                      },
                    ),
                    FilterChip(
                      label: Text('Only local ($localCount)'),
                      selected: _onlyLocal,
                      onSelected: (value) {
                        setState(() => _onlyLocal = value);
                        _saveFilters();
                      },
                    ),
                    FilterChip(
                      label: Text('Only server ($serverCount)'),
                      selected: _onlyServer,
                      onSelected: (value) {
                        setState(() => _onlyServer = value);
                        _saveFilters();
                      },
                    ),
                    ActionChip(
                      label: const Text('Preset: Conflicts'),
                      onPressed: () {
                        setState(() {
                          _onlyDiffs = true;
                          _onlyLocal = false;
                          _onlyServer = false;
                          _entityFilters.clear();
                        });
                        _saveFilters();
                      },
                    ),
                    ActionChip(
                      label: const Text('Preset: Local'),
                      onPressed: () {
                        setState(() {
                          _onlyDiffs = false;
                          _onlyLocal = true;
                          _onlyServer = false;
                          _entityFilters.clear();
                        });
                        _saveFilters();
                      },
                    ),
                    ActionChip(
                      label: const Text('Preset: Server'),
                      onPressed: () {
                        setState(() {
                          _onlyDiffs = false;
                          _onlyLocal = false;
                          _onlyServer = true;
                          _entityFilters.clear();
                        });
                        _saveFilters();
                      },
                    ),
                    ActionChip(
                      label: const Text('Clear filters'),
                      onPressed: () {
                        setState(() {
                          _onlyDiffs = false;
                          _onlyLocal = false;
                          _onlyServer = false;
                          _entityFilters.clear();
                        });
                        _saveFilters();
                      },
                    ),
                    for (final entity in entities)
                      FilterChip(
                        label: Text(entity),
                        selected: _entityFilters.contains(entity),
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _entityFilters.add(entity);
                            } else {
                              _entityFilters.remove(entity);
                            }
                          });
                          _saveFilters();
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text('${item['entity']} ${item['entity_id']}'),
                        subtitle: Text('${item['resolution']} · ${item['created_at']}'),
                        leading: _diffIndicator(item),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _AuditDetailScreen(
                                entity: item['entity'] as String? ?? '',
                                entityId: item['entity_id'] as String? ?? '',
                                resolution: item['resolution'] as String? ?? '',
                                createdAt: item['created_at'] as String? ?? '',
                                localSnapshot: item['local_snapshot'] as String?,
                                serverSnapshot: item['server_snapshot'] as String?,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    return items.where((item) {
      if (_onlyDiffs && !_hasDiffFromItem(item)) {
        return false;
      }
      if (_onlyLocal && item['resolution'] != 'local') {
        return false;
      }
      if (_onlyServer && item['resolution'] != 'server') {
        return false;
      }
      if (_entityFilters.isNotEmpty &&
          !_entityFilters.contains(item['entity'] as String? ?? 'unknown')) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _hasDiffFromItem(Map<String, dynamic> item) {
    final local = _decodeSnapshot(item['local_snapshot'] as String?);
    final server = _decodeSnapshot(item['server_snapshot'] as String?);
    return _hasDiff(local, server);
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onlyDiffs = prefs.getBool('audit_only_diffs') ?? false;
      _onlyLocal = prefs.getBool('audit_only_local') ?? false;
      _onlyServer = prefs.getBool('audit_only_server') ?? false;
      _entityFilters
        ..clear()
        ..addAll(prefs.getStringList('audit_entity_filters') ?? const []);
    });
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audit_only_diffs', _onlyDiffs);
    await prefs.setBool('audit_only_local', _onlyLocal);
    await prefs.setBool('audit_only_server', _onlyServer);
    await prefs.setStringList('audit_entity_filters', _entityFilters.toList());
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Profile Details'),
              subtitle: const Text('Edit personal stats and goals'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileEditorScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Training Preferences'),
              subtitle: const Text('Goals, level, equipment access'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _TrainingPreferencesScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Audio & Timer Cues'),
              subtitle: const Text('Voice, beeps, volumes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _AudioCuesScreen()),
                );
              },
            ),
          ),
          FutureBuilder<_ExportDefaults>(
            future: _loadExportDefaults(),
            builder: (context, snapshot) {
              final defaults = snapshot.data ?? _ExportDefaults();
              return Card(
                child: ListTile(
                  title: const Text('Export Defaults'),
                  subtitle: Text(
                    'Format: ${defaults.formatLabel} · Include snapshots: ${defaults.includeSnapshots ? 'Yes' : 'No'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const _ExportDefaultsScreen()),
                    );
                  },
                ),
              );
            },
          ),
          Card(
            child: ListTile(
              title: const Text('Reset Preferences'),
              subtitle: const Text('Clears saved filters and local preferences'),
              trailing: const Icon(Icons.restart_alt),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preferences reset')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingPreferencesScreen extends StatelessWidget {
  const _TrainingPreferencesScreen();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Training Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Experience Level'),
              subtitle: Text(settings.goalLevel),
              trailing: DropdownButton<String>(
                value: settings.goalLevel,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  settings.updateGoalLevel(value);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Primary Goal'),
              subtitle: Text(settings.goalType),
              trailing: DropdownButton<String>(
                value: settings.goalType,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'strength', child: Text('Strength')),
                  DropdownMenuItem(value: 'hypertrophy', child: Text('Hypertrophy')),
                  DropdownMenuItem(value: 'fat_loss', child: Text('Fat loss')),
                  DropdownMenuItem(value: 'endurance', child: Text('Endurance')),
                  DropdownMenuItem(value: 'recomp', child: Text('Recomposition')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  settings.updateGoalType(value);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Equipment Access'),
              subtitle: Text(settings.equipmentAccess),
              trailing: DropdownButton<String>(
                value: settings.equipmentAccess,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'full_gym', child: Text('Full gym')),
                  DropdownMenuItem(value: 'home_minimal', child: Text('Home minimal')),
                  DropdownMenuItem(value: 'bodyweight', child: Text('Bodyweight only')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  settings.updateEquipmentAccess(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioCuesScreen extends StatelessWidget {
  const _AudioCuesScreen();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Audio & Timer Cues')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Cue Mode'),
              subtitle: Text(settings.audioMode),
              trailing: DropdownButton<String>(
                value: settings.audioMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'off', child: Text('Off')),
                  DropdownMenuItem(value: 'voice', child: Text('Voice')),
                  DropdownMenuItem(value: 'beep', child: Text('Beeps')),
                  DropdownMenuItem(value: 'both', child: Text('Voice + beeps')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  settings.updateAudioMode(value);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Voice Style'),
              subtitle: Text(settings.voiceStyle),
              trailing: DropdownButton<String>(
                value: settings.voiceStyle,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'coach', child: Text('Coach')),
                  DropdownMenuItem(value: 'calm', child: Text('Calm')),
                  DropdownMenuItem(value: 'energetic', child: Text('Energetic')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  settings.updateVoiceStyle(value);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Voice Gender'),
              subtitle: Text(settings.voiceGender),
              trailing: DropdownButton<String>(
                value: settings.voiceGender,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  settings.updateVoiceGender(value);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Voice Volume'),
              subtitle: Text('${(settings.voiceVolume * 100).round()}%'),
            ),
          ),
          Slider(
            value: settings.voiceVolume,
            min: 0.1,
            max: 1.0,
            onChanged: (value) => settings.updateVoiceVolume(value),
          ),
          Card(
            child: ListTile(
              title: const Text('Beep Style'),
              subtitle: Text(settings.beepStyle),
              trailing: DropdownButton<String>(
                value: settings.beepStyle,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'soft', child: Text('Soft')),
                  DropdownMenuItem(value: 'sharp', child: Text('Sharp')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  settings.updateBeepStyle(value);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Beep Tone'),
              subtitle: Text(settings.beepTone),
              trailing: DropdownButton<String>(
                value: settings.beepTone,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'mid', child: Text('Mid')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  settings.updateBeepTone(value);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Beep Volume'),
              subtitle: Text('${(settings.beepVolume * 100).round()}% (system volume)'),
            ),
          ),
          Slider(
            value: settings.beepVolume,
            min: 0.1,
            max: 1.0,
            onChanged: (value) => settings.updateBeepVolume(value),
          ),
        ],
      ),
    );
  }
}

class _ExportDefaults {
  _ExportDefaults({
    this.formatLabel = 'CSV',
    this.includeSnapshots = false,
  });

  final String formatLabel;
  final bool includeSnapshots;
}

class _ExportDefaultsScreen extends StatefulWidget {
  const _ExportDefaultsScreen();

  @override
  State<_ExportDefaultsScreen> createState() => _ExportDefaultsScreenState();
}

class _ExportDefaultsScreenState extends State<_ExportDefaultsScreen> {
  bool _includeSnapshots = false;
  String _format = 'CSV';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final defaults = await _loadExportDefaults();
    if (!mounted) return;
    setState(() {
      _includeSnapshots = defaults.includeSnapshots;
      _format = defaults.formatLabel;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('export_include_snapshots', _includeSnapshots);
    await prefs.setString('export_format', _format);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Defaults')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Include snapshots'),
            subtitle: const Text('Adds local/server JSON to exports'),
            value: _includeSnapshots,
            onChanged: (value) {
              setState(() => _includeSnapshots = value);
              _save();
            },
          ),
          Card(
            child: ListTile(
              title: const Text('Format'),
              subtitle: Text(_format),
              trailing: DropdownButton<String>(
                value: _format,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'CSV', child: Text('CSV')),
                  DropdownMenuItem(value: 'JSON', child: Text('JSON')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _format = value);
                  _save();
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Reset Export Defaults'),
              subtitle: const Text('Restores CSV without snapshots'),
              trailing: const Icon(Icons.restart_alt),
              onTap: () async {
                setState(() {
                  _includeSnapshots = false;
                  _format = 'CSV';
                });
                await _save();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditDetailScreen extends StatelessWidget {
  const _AuditDetailScreen({
    required this.entity,
    required this.entityId,
    required this.resolution,
    required this.createdAt,
    this.localSnapshot,
    this.serverSnapshot,
  });

  final String entity;
  final String entityId;
  final String resolution;
  final String createdAt;
  final String? localSnapshot;
  final String? serverSnapshot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conflict Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entity', style: Theme.of(context).textTheme.titleLarge),
            Text(entity),
            const SizedBox(height: 12),
            Text('ID', style: Theme.of(context).textTheme.titleLarge),
            Text(entityId),
            const SizedBox(height: 12),
            Text('Resolution', style: Theme.of(context).textTheme.titleLarge),
            Text(resolution),
            const SizedBox(height: 12),
            Text('Timestamp', style: Theme.of(context).textTheme.titleLarge),
            Text(createdAt),
            const SizedBox(height: 24),
            Text('Field Diff', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              child: _AuditDiffView(
                localSnapshot: localSnapshot,
                serverSnapshot: serverSnapshot,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditDiffView extends StatelessWidget {
  const _AuditDiffView({required this.localSnapshot, required this.serverSnapshot});

  final String? localSnapshot;
  final String? serverSnapshot;

  @override
  Widget build(BuildContext context) {
    final local = _decodeSnapshot(localSnapshot);
    final server = _decodeSnapshot(serverSnapshot);
    final keys = <String>{}..addAll(local.keys)..addAll(server.keys);
    if (keys.isEmpty) {
      return const Text('No snapshots available.');
    }
    final orderedKeys = keys.toList()..sort();
    return ListView(
      children: [
        for (final key in orderedKeys)
          _AuditDiffRow(
            field: key,
            localValue: local[key],
            serverValue: server[key],
          ),
      ],
    );
  }
}

class _AuditDiffRow extends StatelessWidget {
  const _AuditDiffRow({
    required this.field,
    required this.localValue,
    required this.serverValue,
  });

  final String field;
  final Object? localValue;
  final Object? serverValue;

  @override
  Widget build(BuildContext context) {
    final different = '$localValue' != '$serverValue';
    final color = different ? Colors.amberAccent : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(field, style: TextStyle(color: color))),
          Expanded(child: Text('$localValue', style: TextStyle(color: color))),
          Expanded(child: Text('$serverValue', style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

Map<String, dynamic> _decodeSnapshot(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {}
  return {};
}

String _buildAuditCsv(List<Map<String, dynamic>> rows, bool includeSnapshots) {
  final buffer = StringBuffer();
  buffer.write('entity,entity_id,resolution,created_at');
  if (includeSnapshots) {
    buffer.write(',local_snapshot,server_snapshot');
  }
  buffer.writeln();
  for (final row in rows) {
    final entity = row['entity'] ?? '';
    final entityId = row['entity_id'] ?? '';
    final resolution = row['resolution'] ?? '';
    final createdAt = row['created_at'] ?? '';
    buffer.write('$entity,$entityId,$resolution,$createdAt');
    if (includeSnapshots) {
      final local = row['local_snapshot'] ?? '';
      final server = row['server_snapshot'] ?? '';
      buffer.write(',"${local.toString().replaceAll("\"", "\"\"")}","${server.toString().replaceAll("\"", "\"\"")}"');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes} B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatFullDateTime(DateTime time) {
  final local = time.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute:$second';
}

Future<_ExportDefaults> _loadExportDefaults() async {
  final prefs = await SharedPreferences.getInstance();
  return _ExportDefaults(
    formatLabel: prefs.getString('export_format') ?? 'CSV',
    includeSnapshots: prefs.getBool('export_include_snapshots') ?? false,
  );
}

Future<void> _showCopyExportDialog(BuildContext context, _AuditExport export) {
  bool includeSnapshots = export.includeSnapshots;
  return showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final content = _buildAuditExport(
            export.rows,
            _ExportDefaults(
              formatLabel: export.label,
              includeSnapshots: includeSnapshots,
            ),
          ).content;
          final display = content.split('\n').take(6).join('\n');
          final displaySize = utf8.encode(content).length;
          return AlertDialog(
            title: Text('Copy ${export.label}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Size: ${_formatBytes(displaySize)}'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include snapshots'),
                  value: includeSnapshots,
                  onChanged: (value) async {
                    setState(() => includeSnapshots = value);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('export_include_snapshots', includeSnapshots);
                  },
                ),
                const SizedBox(height: 8),
                Text('Preview:'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: export.label == 'JSON'
                      ? HighlightView(
                          _prettyJson(display),
                          language: 'json',
                          theme: atomOneDarkTheme,
                          textStyle: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                        )
                      : Text(
                          display,
                          style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${export.label} copied (${_formatBytes(displaySize)})')),
                  );
                },
                child: const Text('Copy'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _AuditExport {
  _AuditExport({
    required this.label,
    required this.extension,
    required this.content,
    required this.rows,
    required this.includeSnapshots,
  });

  final String label;
  final String extension;
  final String content;
  final List<Map<String, dynamic>> rows;
  final bool includeSnapshots;
}

_AuditExport _buildAuditExport(List<Map<String, dynamic>> rows, _ExportDefaults defaults) {
  if (defaults.formatLabel == 'JSON') {
    final data = rows
        .map((row) {
          final base = {
            'entity': row['entity'],
            'entity_id': row['entity_id'],
            'resolution': row['resolution'],
            'created_at': row['created_at'],
          };
          if (defaults.includeSnapshots) {
            base['local_snapshot'] = row['local_snapshot'];
            base['server_snapshot'] = row['server_snapshot'];
          }
          return base;
        })
        .toList();
    return _AuditExport(
      label: 'JSON',
      extension: 'json',
      content: const JsonEncoder.withIndent('  ').convert(data),
      rows: rows,
      includeSnapshots: defaults.includeSnapshots,
    );
  }
  return _AuditExport(
    label: 'CSV',
    extension: 'csv',
    content: _buildAuditCsv(rows, defaults.includeSnapshots),
    rows: rows,
    includeSnapshots: defaults.includeSnapshots,
  );
}

String _prettyJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return raw;
  }
}

Widget _diffIndicator(Map<String, dynamic> item) {
  final local = _decodeSnapshot(item['local_snapshot'] as String?);
  final server = _decodeSnapshot(item['server_snapshot'] as String?);
  final hasDiff = _hasDiff(local, server);
  return Icon(
    hasDiff ? Icons.warning_amber : Icons.check_circle,
    color: hasDiff ? Colors.amberAccent : Colors.greenAccent,
  );
}

bool _hasDiff(Map<String, dynamic> local, Map<String, dynamic> server) {
  final keys = <String>{}..addAll(local.keys)..addAll(server.keys);
  for (final key in keys) {
    if ('${local[key]}' != '${server[key]}') {
      return true;
    }
  }
  return false;
}
