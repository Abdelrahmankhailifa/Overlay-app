import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_channel.dart';
import 'app_picker_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _focusModeEnabled = false;
  int _selectedAppsCount = 0;
  bool _hasOverlayPermission = false;
  bool _hasUsageStatsPermission = false;
  bool _isLoading = true;

  String? _overlayImagePath;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedApps = prefs.getStringList('selected_apps') ?? [];
    final focusMode = prefs.getBool('focus_mode') ?? false;
    final imagePath = prefs.getString('overlay_image');
    
    final hasOverlay = await PlatformChannel.hasOverlayPermission();
    final hasUsageStats = await PlatformChannel.hasUsageStatsPermission();

    setState(() {
      _selectedAppsCount = selectedApps.length;
      _focusModeEnabled = focusMode;
      _overlayImagePath = imagePath;
      _hasOverlayPermission = hasOverlay;
      _hasUsageStatsPermission = hasUsageStats;
      _isLoading = false;
    });
  }

  Future<void> _toggleFocusMode(bool value) async {
    // Check permissions first
    if (!_hasOverlayPermission || !_hasUsageStatsPermission) {
      _showPermissionDialog();
      return;
    }

    if (_selectedAppsCount == 0) {
      _showNoAppsDialog();
      return;
    }

    if (value && _overlayImagePath == null) {
      final shouldUseDefault = await _showNoImageDialog();
      if (shouldUseDefault != true) {
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('focus_mode', value);
    await PlatformChannel.setFocusMode(value);

    setState(() {
      _focusModeEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Focus Mode Enabled' : 'Focus Mode Disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<bool?> _showNoImageDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Overlay Image Selected'),
        content: const Text(
          'You haven\'t selected an image for the overlay. A default dark screen will be used instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadState());
            },
            child: const Text('Select Image'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Default'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'This app requires the following permissions:\n\n'
          '• Display over other apps\n'
          '• Usage access\n\n'
          'Please grant these permissions in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadState());
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  void _showNoAppsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Apps Selected'),
        content: const Text(
          'Please select at least one app to monitor before enabling Focus Mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppPickerScreen()),
              ).then((_) => _loadState());
            },
            child: const Text('Select Apps'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Overlay'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadState());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Focus Mode Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        _focusModeEnabled ? Icons.visibility_off : Icons.visibility,
                        size: 64,
                        color: _focusModeEnabled
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Focus Mode',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _focusModeEnabled
                            ? 'Overlay is active on selected apps'
                            : 'Overlay is currently disabled',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Switch(
                        value: _focusModeEnabled,
                        onChanged: _toggleFocusMode,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Selected Apps Card
              Card(
                child: ListTile(
                  leading: const Icon(Icons.apps),
                  title: const Text('Selected Apps'),
                  subtitle: Text('$_selectedAppsCount apps will trigger overlay'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AppPickerScreen()),
                    ).then((_) => _loadState());
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Permissions Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permissions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildPermissionRow(
                        'Display over other apps',
                        _hasOverlayPermission,
                      ),
                      const SizedBox(height: 8),
                      _buildPermissionRow(
                        'Usage access',
                        _hasUsageStatsPermission,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Info Card
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'When Focus Mode is enabled, selected apps will show your overlay image.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRow(String label, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
