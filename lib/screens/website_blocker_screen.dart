import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_channel.dart';
import '../services/pin_service.dart';
import 'widgets/pin_dialog.dart';

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
  }

  Future<void> _checkPermission() async {
    final hasPermission = await PlatformChannel.hasAccessibilityPermission();
    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
      });
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Block Websites'),
      ),
      body: Column(
        children: [
          // Permission Warning
          if (!_hasPermission)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade100,
              child: Column(
                children: [
                   Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Website blocking requires Accessibility Service permission.",
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Enable Permission"),
                  ),
                ],
              ),
            ),

          // Add Website Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'example.com',
                      labelText: 'Block Website',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.public),
                    ),
                    onSubmitted: (_) => _addWebsite(),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  onPressed: _addWebsite,
                  icon: const Icon(Icons.add),
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
                        Icon(Icons.block, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "No websites blocked",
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _blockedWebsites.length,
                    itemBuilder: (context, index) {
                      final site = _blockedWebsites[index];
                      return ListTile(
                        leading: const Icon(Icons.public_off, color: Colors.red),
                        title: Text(site),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeWebsite(site),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
