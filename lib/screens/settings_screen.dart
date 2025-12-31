import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../services/platform_channel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _overlayImagePath;
  bool _hasOverlayPermission = false;
  bool _hasUsageStatsPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('overlay_image');
    
    final hasOverlay = await PlatformChannel.hasOverlayPermission();
    final hasUsageStats = await PlatformChannel.hasUsageStatsPermission();

    setState(() {
      _overlayImagePath = imagePath;
      _hasOverlayPermission = hasOverlay;
      _hasUsageStatsPermission = hasUsageStats;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Copy image to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'overlay_image.${image.path.split('.').last}';
      final savedImage = File('${appDir.path}/$fileName');
      await File(image.path).copy(savedImage.path);

      // Save path to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('overlay_image', savedImage.path);
      await PlatformChannel.setOverlayImage(savedImage.path);

      setState(() {
        _overlayImagePath = savedImage.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Overlay image updated'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _requestOverlayPermission() async {
    final granted = await PlatformChannel.requestOverlayPermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Overlay permission granted'
                : 'Please grant overlay permission in Settings',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadSettings();
    }
  }

  Future<void> _requestUsageStatsPermission() async {
    final granted = await PlatformChannel.requestUsageStatsPermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Usage access granted'
                : 'Please grant usage access in Settings',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadSettings();
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will remove all selected apps and overlay image. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await PlatformChannel.setFocusMode(false);
      await PlatformChannel.setSelectedApps([]);

      setState(() {
        _overlayImagePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Overlay Image Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overlay Image',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_overlayImagePath != null)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_overlayImagePath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: Text(
                    _overlayImagePath == null
                        ? 'Select Overlay Image'
                        : 'Change Overlay Image',
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Permissions Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permissions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    _hasOverlayPermission ? Icons.check_circle : Icons.cancel,
                    color: _hasOverlayPermission ? Colors.green : Colors.red,
                  ),
                  title: const Text('Display over other apps'),
                  subtitle: Text(
                    _hasOverlayPermission ? 'Granted' : 'Not granted',
                  ),
                  trailing: _hasOverlayPermission
                      ? null
                      : ElevatedButton(
                          onPressed: _requestOverlayPermission,
                          child: const Text('Grant'),
                        ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(
                    _hasUsageStatsPermission ? Icons.check_circle : Icons.cancel,
                    color: _hasUsageStatsPermission ? Colors.green : Colors.red,
                  ),
                  title: const Text('Usage access'),
                  subtitle: Text(
                    _hasUsageStatsPermission ? 'Granted' : 'Not granted',
                  ),
                  trailing: _hasUsageStatsPermission
                      ? null
                      : ElevatedButton(
                          onPressed: _requestUsageStatsPermission,
                          child: const Text('Grant'),
                        ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Data Management
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Management',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _clearData,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear All Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // About Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Focus Overlay helps you stay focused by displaying a custom image when you open distracting apps.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
