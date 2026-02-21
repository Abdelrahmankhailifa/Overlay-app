import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_channel.dart';
import 'website_blocker_screen.dart';
import 'package:showcaseview/showcaseview.dart';
import '../utils/walkthrough_keys.dart';
import '../services/walkthrough_service.dart';

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key});

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<Application> _allApps = [];
  List<Application> _filteredApps = [];
  Set<String> _selectedPackages = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadApps();
    
     // Check and start walkthrough
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartWalkthrough();
    });
  }

  Future<void> _checkAndStartWalkthrough() async {
    if (await WalkthroughService().shouldShowAppPickerWalkthrough()) {
      if (mounted) {
        ShowCaseWidget.of(context).startShowCase([
          WalkthroughKeys.searchBar,
          WalkthroughKeys.saveButton,
        ]);
        WalkthroughService().markAppPickerWalkthroughComplete();
      }
    }
  }

  // ... (keep _loadApps, _filterApps, _saveSelection)

  Future<void> _loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedApps = prefs.getStringList('selected_apps') ?? [];

    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: false,
      onlyAppsWithLaunchIntent: true,
    );

    apps.sort((a, b) => a.appName.compareTo(b.appName));

    setState(() {
      _allApps = apps;
      _filteredApps = apps;
      _selectedPackages = selectedApps.toSet();
      _isLoading = false;
    });
  }

  void _filterApps(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredApps = _allApps;
      } else {
        _filteredApps = _allApps
            .where((app) =>
                app.appName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_apps', _selectedPackages.toList());
    await PlatformChannel.setSelectedApps(_selectedPackages.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedPackages.length} apps selected'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ShowCaseWidget(
      builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Select Apps'),
              actions: [
                Showcase(
                  key: WalkthroughKeys.saveButton,
                  title: 'Confirm Selection',
                  description: 'Tap here to save your selection.',
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      onPressed: _selectedPackages.isEmpty ? null : _saveSelection,
                      icon: const Icon(Icons.check),
                      label: const Text('SAVE'),
                      style: TextButton.styleFrom(
                        backgroundColor: _selectedPackages.isEmpty 
                            ? null 
                            : colorScheme.primaryContainer,
                        foregroundColor: _selectedPackages.isEmpty 
                            ? null 
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Showcase(
                    key: WalkthroughKeys.searchBar,
                    title: 'Search Applications',
                    description: 'Search for apps to block.',
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: _filterApps,
                    ),
                  ),
                ),

                // Selected count
                if (_selectedPackages.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedPackages.length} apps selected',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Apps List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredApps.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No apps found',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredApps.length,
                              itemBuilder: (context, index) {
                                final app = _filteredApps[index];
                                final isSelected =
                                    _selectedPackages.contains(app.packageName);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? colorScheme.primaryContainer.withOpacity(0.3)
                                        : colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected 
                                          ? colorScheme.primary.withOpacity(0.5)
                                          : colorScheme.outlineVariant.withOpacity(0.3),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedPackages.add(app.packageName);
                                        } else {
                                          _selectedPackages.remove(app.packageName);
                                        }
                                      });
                                    },
                                    title: Text(
                                      app.appName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    secondary: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: app is ApplicationWithIcon
                                          ? Image.memory(
                                              app.icon,
                                              width: 32,
                                              height: 32,
                                            )
                                          : const Icon(Icons.android, size: 32),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
    );
  }
}
