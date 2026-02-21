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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _loadState();
    
    // Check global walkthrough status once frame is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGlobalWalkthrough();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tourContinuationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload state when app resumes from background
    if (state == AppLifecycleState.resumed) {
      _loadState();
    }
  }

  Future<void> _checkGlobalWalkthrough() async {
    final status = await WalkthroughService().getGlobalWalkthroughStatus();
    
    if (status == 'pending' || status == 'later') {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Welcome to BreakLooplay!'),
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 0,
              centerTitle: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: Text(
                'Dashboard',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              actions: [
                Showcase(
                  key: WalkthroughKeys.settingsButton,
                  description: 'Customize your experience, set PIN, and more.',
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
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
                ),
              ],
            ),
            
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Focus Mode Card
                  Showcase(
                    key: WalkthroughKeys.focusModeCard,
                    description: 'Enable Focus Mode to block distractions.',
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _focusModeEnabled
                              ? [colorScheme.primary, colorScheme.primary.withOpacity(0.8)]
                              : [colorScheme.surface, colorScheme.surface],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _focusModeEnabled
                                ? colorScheme.primary.withOpacity(0.3)
                                .withAlpha(80) 
                                : Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: _focusModeEnabled 
                            ? null 
                            : Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _focusModeEnabled
                                          ? Colors.white.withOpacity(0.2)
                                          : colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      _focusModeEnabled ? Icons.bolt : Icons.bolt_outlined,
                                      color: _focusModeEnabled
                                          ? Colors.white
                                          : colorScheme.primary,
                                      size: 28,
                                    ),
                                  ),
                                  Showcase(
                                    key: WalkthroughKeys.focusModeSwitch,
                                    description: 'Toggle Focus Mode',
                                    child: Transform.scale(
                                      scale: 1.2,
                                      child: Switch(
                                        value: _focusModeEnabled,
                                        onChanged: _toggleFocusMode,
                                        activeColor: Colors.white,
                                        activeTrackColor: Colors.white.withOpacity(0.3),
                                        inactiveThumbColor: colorScheme.outline,
                                        inactiveTrackColor: Colors.transparent, 
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _focusModeEnabled ? 'Focus Mode Active' : 'Focus Mode Off',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _focusModeEnabled ? Colors.white : colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _focusModeEnabled
                                    ? 'Distractions are being blocked.'
                                    : 'Enable to start blocking distractions.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _focusModeEnabled
                                      ? Colors.white.withOpacity(0.9)
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Permissions Section (only if needed)
                  if (!_hasOverlayPermission || !_hasUsageStatsPermission || _isBatteryOptimized)
                    Showcase(
                      key: WalkthroughKeys.permissionsCard,
                      description: 'Required permissions for the app to function.',
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
                                const SizedBox(width: 12),
                                Text(
                                  'Action Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (!_hasOverlayPermission)
                              _buildPermissionAction(
                                'Display over other apps',
                                'Detects when you open apps',
                                () async {
                                  await PlatformChannel.requestOverlayPermission();
                                  _loadState();
                                },
                              ),
                            if (!_hasUsageStatsPermission)
                              _buildPermissionAction(
                                'Usage Access',
                                'Detects usage time',
                                () async {
                                  await PlatformChannel.requestUsageStatsPermission();
                                  _loadState();
                                },
                              ),
                            if (_isBatteryOptimized)
                              _buildPermissionAction(
                                'Disable Battery Opt.',
                                'Prevents app from closing',
                                () async {
                                  await PlatformChannel.requestBatteryOptimization();
                                  _loadState();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Actions Grid
                  Row(
                    children: [
                      Expanded(
                        child: Showcase(
                          key: WalkthroughKeys.addAppsButton,
                          description: 'Select apps to block.',
                          child: _buildActionButton(
                            context,
                            'Apps',
                            Icons.apps_rounded,
                            Colors.blue,
                            () {
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Showcase(
                          key: WalkthroughKeys.blockWebsitesButton,
                          description: 'Select websites to block.',
                          child: _buildActionButton(
                            context,
                            'Websites',
                            Icons.public,
                            Colors.orange,
                            () {
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
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Section Title
                  Row(
                    children: [
                      Text(
                        'Blocked Items',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_selectedAppsCount + _blockedWebsitesCount}',
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),

            if (_selectedApps.isEmpty && _blockedWebsitesCount == 0)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
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
                            Icons.layers_clear_outlined,
                            size: 48,
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No blocks configured',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select apps or websites to start focusing.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final app = _selectedApps[index];
                      final isFirst = index == 0;
                      
                      final item = Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: app is ApplicationWithIcon
                                ? Image.memory(app.icon, width: 24, height: 24)
                                : const Icon(Icons.android, size: 24),
                          ),
                          title: Text(
                            app.appName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            app.packageName,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Showcase(
                            key: isFirst ? WalkthroughKeys.removeAppButton : GlobalKey(),
                            description: 'Remove from block list.',
                            child: IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                              onPressed: () => _removeApp(app.packageName),
                            ),
                          ),
                        ),
                      );

                      if (isFirst) {
                        return Showcase(
                          key: WalkthroughKeys.appListItem,
                          description: 'Blocked app.',
                          child: item,
                        );
                      }
                      return item;
                    },
                    childCount: _selectedApps.length,
                  ),
                ),
              ),
              
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
            boxShadow: [
               BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionAction(String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: Colors.amber.withOpacity(0.2),
              foregroundColor: Colors.amber[900],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Fix', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String label, bool granted) {
    final color = granted ? Colors.green : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
