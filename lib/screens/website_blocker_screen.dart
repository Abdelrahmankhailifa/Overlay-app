import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_channel.dart';
import '../services/pin_service.dart';
import 'widgets/pin_dialog.dart';
import 'package:showcaseview/showcaseview.dart';
import '../utils/walkthrough_keys.dart';
import '../services/walkthrough_service.dart';

class WebsiteBlockerScreen extends StatefulWidget {
  const WebsiteBlockerScreen({super.key});

  @override
  State<WebsiteBlockerScreen> createState() => _WebsiteBlockerScreenState();
}

class _WebsiteBlockerScreenState extends State<WebsiteBlockerScreen> {
  List<String> _blockedWebsites = [];
  final TextEditingController _urlController = TextEditingController();
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadBlockedWebsites();
    _checkPermission();

     // Check and start walkthrough
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartWalkthrough();
    });
  }

  Future<void> _checkAndStartWalkthrough() async {
    if (await WalkthroughService().shouldShowWebsiteBlockerWalkthrough()) {
      if (mounted) {
        // Collect targets, might depend on permission state
        final targets = [
          if (!_hasPermission) WalkthroughKeys.accessibilityWarning,
          WalkthroughKeys.urlInputField,
          WalkthroughKeys.addWebsiteButton,
        ];
        
        // Only start if we have targets
        if (targets.isNotEmpty) {
           ShowCaseWidget.of(context).startShowCase(targets);
           WalkthroughService().markWebsiteBlockerWalkthroughComplete();
        }
      }
    }
  }

  Future<void> _checkPermission() async {
    final hasPermission = await PlatformChannel.hasAccessibilityPermission();
    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
      });
    }
  }

  // ... (keep requestPermission, loadBlockedWebsites, addWebsite, removeWebsite, saveWebsites)

  Future<void> _requestPermission() async {
    await PlatformChannel.requestAccessibilityPermission();
    // Recheck after returning from settings (users might have enabled it)
    await Future.delayed(const Duration(seconds: 1)); 
    // Usually we would listen to lifecycle changes (resumed), but a delay/refresh is a simple start
    _checkPermission(); 
  }

  // Reload permission when app resumes (simple focus check in build might not catch it immediately without observer)
  // For better UX, we could use WidgetsBindingObserver

  Future<void> _loadBlockedWebsites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _blockedWebsites = prefs.getStringList('blocked_websites') ?? [];
    });
  }

  Future<void> _addWebsite() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Simple cleanup
    url = url.toLowerCase()
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('www.', '');
    
    // Remove trailing slash
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (!_blockedWebsites.contains(url)) {
      setState(() {
        _blockedWebsites.add(url);
      });
      _urlController.clear();
      await _saveWebsites();
    }
  }

  Future<void> _removeWebsite(String url) async {
    final hasPin = await PinService().isPinSet();
    
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinDialog(
        title: hasPin ? 'Enter PIN to Remove Website' : 'Create PIN to Remove Website',
        isSettingPin: !hasPin,
      ),
    );
    
    if (verified != true) return;

    setState(() {
      _blockedWebsites.remove(url);
    });
    await _saveWebsites();
  }

  Future<void> _saveWebsites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_websites', _blockedWebsites);
    await PlatformChannel.setBlockedWebsites(_blockedWebsites);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ShowCaseWidget(
      builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Block Websites'),
            ),
            body: Column(
              children: [
                // Permission Warning
                if (!_hasPermission)
                  Showcase(
                    key: WalkthroughKeys.accessibilityWarning,
                    title: 'Permission Required',
                    description: 'Enable Accessibility Service to block websites.',
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                           Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Accessibility permission required",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _requestPermission,
                            icon: const Icon(Icons.settings),
                            label: const Text("Enable Permission"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Add Website Input
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Showcase(
                          key: WalkthroughKeys.urlInputField,
                          title: 'Website URL',
                          description: 'Enter the website to block.',
                          child: TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              hintText: 'example.com',
                              labelText: 'Website URL',
                              prefixIcon: Icon(Icons.public),
                            ),
                            onSubmitted: (_) => _addWebsite(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Showcase(
                        key: WalkthroughKeys.addWebsiteButton,
                        title: 'Add Website',
                        description: 'Tap to add the website.',
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: _addWebsite,
                            icon: const Icon(Icons.add_rounded),
                            tooltip: 'Add',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: _blockedWebsites.isEmpty
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
                                  Icons.block_outlined,
                                  size: 48,
                                  color: colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No websites blocked",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _blockedWebsites.length,
                          itemBuilder: (context, index) {
                            final site = _blockedWebsites[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withOpacity(0.3),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.public_off_rounded,
                                    color: colorScheme.error,
                                  ),
                                ),
                                title: Text(
                                  site,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: () => _removeWebsite(site),
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
