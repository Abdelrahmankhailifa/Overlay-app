import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';
import '../services/platform_channel.dart';
import '../services/pin_service.dart';
import 'app_picker_screen.dart';
import 'settings_screen.dart';
import 'widgets/pin_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _focusModeEnabled = false;
  List<Application> _selectedApps = [];
  int _selectedAppsCount = 0;
  bool _hasOverlayPermission = false;
  bool _hasUsageStatsPermission = false;
  bool _isBatteryOptimized = false;
  bool _isLoading = true;

  String? _overlayImagePath;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedPackageNames = prefs.getStringList('selected_apps') ?? [];
    final focusMode = prefs.getBool('focus_mode') ?? false;
    final imagePath = prefs.getString('overlay_image');
    
    final hasOverlay = await PlatformChannel.hasOverlayPermission();
    final hasUsageStats = await PlatformChannel.hasUsageStatsPermission();
    final isBatteryIgnored = await PlatformChannel.isBatteryOptimizationIgnored();

    // Fetch app details for the selected packages
    List<Application> apps = [];
    for (String pkg in selectedPackageNames) {
      final app = await DeviceApps.getApp(pkg, true);
      if (app != null) {
        apps.add(app);
      }
    }
    apps.sort((a, b) => a.appName.compareTo(b.appName));

    setState(() {
      _selectedApps = apps;
      _selectedAppsCount = apps.length;
      _focusModeEnabled = focusMode;
      _overlayImagePath = imagePath;
      _hasOverlayPermission = hasOverlay;
      _hasUsageStatsPermission = hasUsageStats;
      _isBatteryOptimized = !isBatteryIgnored;
      _isLoading = false;
    });
  }

  Future<void> _removeApp(String packageName) async {
    // Check for PIN
    final hasPin = await PinService().isPinSet();
    
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinDialog(
        title: hasPin ? 'Enter PIN to Remove App' : 'Create PIN to Remove Apps',
        isSettingPin: !hasPin,
      ),
    );
    
    if (verified != true) return;

    final prefs = await SharedPreferences.getInstance();
    final selectedApps = prefs.getStringList('selected_apps') ?? [];
    selectedApps.remove(packageName);
    
    await prefs.setStringList('selected_apps', selectedApps);
    await PlatformChannel.setSelectedApps(selectedApps);
    
    // Reload state to update UI
    _loadState();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App removed from overlay list'),
          duration: Duration(seconds: 1),
        ),
      );
    }
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

    if (!value) {
      // Turning OFF focus mode - Check PIN
      final hasPin = await PinService().isPinSet();
      
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PinDialog(
          title: hasPin ? 'Enter PIN to Disable Focus' : 'Create PIN to Disable Focus',
          isSettingPin: !hasPin,
        ),
      );
      
      if (verified != true) {
        // Reset switch if canceled
        setState(() {
          _focusModeEnabled = true;
        });
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
                      const SizedBox(height: 8),
                      _buildPermissionRow(
                        'Battery unoptimized',
                        !_isBatteryOptimized,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isBatteryOptimized) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.orange.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'App might close in background due to battery optimization.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () async {
                            await PlatformChannel.requestBatteryOptimization();
                            _loadState();
                          },
                          child: const Text('DISABLE OPTIMIZATION'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Selected Apps Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monitored Apps',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AppPickerScreen()),
                      ).then((_) => _loadState());
                    },
                    label: const Text('Add Apps'),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_selectedApps.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.apps_outage, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No apps selected for overlay',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _selectedApps.length,
                    itemBuilder: (context, index) {
                      final app = _selectedApps[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: app is ApplicationWithIcon
                              ? Image.memory(app.icon, width: 32, height: 32)
                              : const Icon(Icons.android),
                          title: Text(app.appName),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _removeApp(app.packageName),
                            tooltip: 'Remove',
                          ),
                        ),
                      );
                    },
                  ),
                ),

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
