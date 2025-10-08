import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../services/user_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Set<String> _selectedRoles = {};
  Set<String> _availableRoles = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Fetch all roles from the API (not just from loaded events)
    final rolesFromApi = await UserService.getAllRoles();

    // Load user's preferred roles
    final preferredRoles = await UserService.getPreferredRoles();

    if (mounted) {
      setState(() {
        _availableRoles = rolesFromApi.toSet();
        _selectedRoles = preferredRoles;
        _loading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    try {
      await UserService.setPreferredRoles(_selectedRoles);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh data to apply filters
        context.read<DataService>().forceRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _savePreferences,
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.work_outline,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Role Preferences',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select the roles you\'re interested in. Only selected roles will appear in your Roles tab.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_availableRoles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No roles available yet',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableRoles.map((role) {
                              final isSelected = _selectedRoles.contains(role);
                              return FilterChip(
                                label: Text(role),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedRoles.add(role);
                                    } else {
                                      _selectedRoles.remove(role);
                                    }
                                  });
                                },
                                selectedColor: theme.colorScheme.primaryContainer,
                                checkmarkColor: theme.colorScheme.onPrimaryContainer,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedRoles = Set.from(_availableRoles);
                                });
                              },
                              icon: const Icon(Icons.select_all, size: 18),
                              label: const Text('Select All'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedRoles.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              label: const Text('Clear All'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('About Role Filtering'),
                    subtitle: const Text(
                      'When no roles are selected, all available roles will be shown. Select specific roles to filter your job listings.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
