import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/platform_channel.dart';
import '../services/pin_service.dart';
import '../services/walkthrough_service.dart';
import '../utils/walkthrough_keys.dart';
import 'app_picker_screen.dart';
import 'settings_screen.dart';
import 'website_blocker_screen.dart';
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
  int _blockedWebsitesCount = 0;
  bool _hasOverlayPermission = false;
  bool _hasUsageStatsPermission = false;
  bool _isBatteryOptimized = false;
  bool _isLoading = true;

  String? _overlayImagePath;

  int _guidedTourStep = 0; // 0: Idle, 1: Homepage, 2: Settings, 3: Apps, 4: Websites, 5: Complete
  Timer? _tourContinuationTimer;

  @override
  void initState() {
    super.initState();
    _loadState();
    
    // Check global walkthrough status once frame is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGlobalWalkthrough();
    });
  }

  Future<void> _checkGlobalWalkthrough() async {
    final status = await WalkthroughService().getGlobalWalkthroughStatus();
    
    if (status == 'pending' || status == 'later') {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Welcome to Focus Overlay!'),
          content: const Text(
            'Would you like a quick interactive tour to set up your preferences and learn how to use the app?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await WalkthroughService().setGlobalWalkthroughStatus('never');
              },
              child: const Text('Never Ask Again'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await WalkthroughService().setGlobalWalkthroughStatus('later');
              },
              child: const Text('Ask Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await WalkthroughService().setGlobalWalkthroughStatus('completed'); // Marked as started/completed
                _startGuidedTour();
              },
              child: const Text('Start Tour'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _startGuidedTour() async {
    // Reset all child walkthroughs so they show up
    await WalkthroughService().resetAllWalkthroughs();
    
    setState(() {
      _guidedTourStep = 1; // Starting homepage walkthrough
    });

    if (!mounted) return;
    
    // Start with Homepage walkthrough
    ShowCaseWidget.of(context).startShowCase([
      WalkthroughKeys.focusModeCard,
      WalkthroughKeys.focusModeSwitch,
      WalkthroughKeys.permissionsCard,
    ]);
    
    // Start a timer to check when homepage walkthrough completes
    _tourContinuationTimer?.cancel();
    _tourContinuationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_guidedTourStep == 1) {
        // Check if homepage walkthrough is marked as complete
        final homeComplete = !(await WalkthroughService().shouldShowHomeWalkthrough());
        if (homeComplete && mounted) {
          timer.cancel();
          _continueTour();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _continueTour() {
    if (!mounted) return;

    if (_guidedTourStep == 1) {
      // Completed homepage, now navigate to Settings
      setState(() => _guidedTourStep = 2);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      ).then((_) {
        _loadState();
        if (_guidedTourStep == 2) {
          setState(() => _guidedTourStep = 3);
          _continueTour();
        }
      });
    } else if (_guidedTourStep == 3) {
      // Returned from Settings, now highlight Apps button
      ShowCaseWidget.of(context).startShowCase([WalkthroughKeys.addAppsButton]);
    } else if (_guidedTourStep == 4) {
      // Returned from Apps, now highlight Websites button
      ShowCaseWidget.of(context).startShowCase([WalkthroughKeys.blockWebsitesButton]);
    } else if (_guidedTourStep == 5) {
      // Finished
      setState(() {
        _guidedTourStep = 0;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tour Completed!'),
          content: const Text(
            'You are all set! You can access these settings anytime. Enable Focus Mode when you are ready to focus.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  // Keep _startWalkthrough for legacy/manual calls if needed, or remove. 
  // keeping it private but unused directly in this flow.
  void _startLegacyWalkthrough() {
     ShowCaseWidget.of(context).startShowCase([
      WalkthroughKeys.focusModeCard,
      WalkthroughKeys.focusModeSwitch,
      WalkthroughKeys.permissionsCard,
      WalkthroughKeys.blockWebsitesButton,
      WalkthroughKeys.addAppsButton,
      WalkthroughKeys.settingsButton,
      if (_selectedApps.isNotEmpty) WalkthroughKeys.appListItem,
      if (_selectedApps.isNotEmpty) WalkthroughKeys.removeAppButton,
    ]);
  }

  // ... (keep _loadState and others)

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    // ... (rest of _loadState implementation)
    final selectedPackageNames = prefs.getStringList('selected_apps') ?? [];
    final blockedWebsites = prefs.getStringList('blocked_websites') ?? [];
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
      _blockedWebsitesCount = blockedWebsites.length;
      _focusModeEnabled = focusMode;
      _overlayImagePath = imagePath;
      _hasOverlayPermission = hasOverlay;
      _hasUsageStatsPermission = hasUsageStats;
      _isBatteryOptimized = !isBatteryIgnored;
      _isLoading = false;
    });

    // Removed _checkAndStartWalkthrough() call from here to avoid conflict with global tour
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

    if (_selectedAppsCount == 0 && _blockedWebsitesCount == 0) {
      _showNoSelectionDialog();
      return;
    }

    if (value && _overlayImagePath == null) {
      final shouldUseColor = await _showNoImageDialog();
      if (shouldUseColor != true) {
        return;
      }
      // Switch to color mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('overlay_type', 'color');
      // Ensure color settings are applied (loaded from prefs in native side or we might need to resend them? 
      // Usually native side loads from prefs or we should send them. 
      // Safest is to just set type to color, native side should handle it if previously saved. 
      // But verify if we need to send color data. 
      // For now, just setting type.
      await PlatformChannel.setOverlayType('color');
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
        // title: const Text('No Overlay Image Selected'),
        // Changing title/content to match user request
        title: const Text('No Image Selected'),
        content: const Text(
          'You haven\'t selected an image. Would you like to use your custom Color Overlay instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
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
            onPressed: () => Navigator.pop(context, true), // Use Color
            child: const Text('Use Color Overlay'),
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

  void _showNoSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Apps or Websites Selected'),
        content: const Text(
          'Please select at least one app or website to monitor before enabling Focus Mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WebsiteBlockerScreen()),
              ).then((_) => _loadState());
            },
            child: const Text('Select Websites'),
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
          Showcase(
            key: WalkthroughKeys.settingsButton,
            description: 'This is your command center. Customize the overlay appearance, set up PIN protection, and configure advanced settings to tailor the experience to your needs.',
            child: IconButton(
              icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  ).then((result) {
                    _loadState();
                    if (result == 'start_tour') {
                      _startGuidedTour();
                    }
                  });
                },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ... (keep Focus Mode Card)
              Showcase(
                key: WalkthroughKeys.focusModeCard,
                description: 'This is the master switch for your productivity. When enabled, the app will actively monitor and block the applications and websites you have selected.',
                 child: Card(
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
                        Showcase(
                          key: WalkthroughKeys.focusModeSwitch,
                          description: 'Flip this switch to engage Focus Mode. For added accountability, you can set a PIN in settings to prevent yourself from turning it off too easily.',
                          child: Switch(
                            value: _focusModeEnabled,
                            onChanged: _toggleFocusMode,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ... (keep Permissions Status)
               Showcase(
                key: WalkthroughKeys.permissionsCard,
                description: 'Ensure these permissions are granted for seamless operation. "Display over other apps" allows the overlay to appear, and "Usage access" lets the app detect when you open distractions.',
                child: Card(
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
                    'Blocking List',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      Showcase(
                        key: WalkthroughKeys.blockWebsitesButton,
                        description: 'Identify the websites that distract you the most. You can block specific URLs or category to keep your browsing habits in check.',
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const WebsiteBlockerScreen()),
                            ).then((_) {
                               _loadState();
                               if (_guidedTourStep == 4) {
                                 setState(() => _guidedTourStep = 5);
                                 _continueTour();
                               }
                            });
                          },
                          label: const Text('Websites'),
                          icon: const Icon(Icons.public),
                          style: TextButton.styleFrom(foregroundColor: Colors.blue),
                        ),
                      ),
                      Showcase(
                        key: WalkthroughKeys.addAppsButton,
                        description: 'Choose the applications you want to restrict. Tapping here allows you to build your list of improved focus targets.',
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AppPickerScreen()),
                            ).then((_) {
                              _loadState();
                              if (_guidedTourStep == 3) {
                                setState(() => _guidedTourStep = 4);
                                _continueTour();
                              }
                            });
                          },
                          label: const Text('Apps'),
                          icon: const Icon(Icons.apps),
                        ),
                      ),
                    ],
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
                      final widget = Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: app is ApplicationWithIcon
                              ? Image.memory(app.icon, width: 32, height: 32)
                              : const Icon(Icons.android),
                          title: Text(app.appName),
                          trailing: Showcase(
                            key: index == 0 ? WalkthroughKeys.removeAppButton : GlobalKey(),
                            description: 'Changed your mind? Tap here to remove an app from your blocked list. If a PIN is set, you will need it to verify this action.',
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _removeApp(app.packageName),
                              tooltip: 'Remove',
                            ),
                          ),
                        ),
                      );
                      
                      // Only showcase the first item
                      if (index == 0) {
                        return Showcase(
                          key: WalkthroughKeys.appListItem,
                          description: 'Here are the apps you have chosen to block. Focus Mode will apply the overlay to these applications when they are opened.',
                          child: widget,
                        );
                      }
                      return widget;
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
