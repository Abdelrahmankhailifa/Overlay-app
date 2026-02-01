import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../services/platform_channel.dart';
import '../services/pin_service.dart';
import 'widgets/pin_dialog.dart';

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

  bool _strictModeEnabled = false;
  bool _hasPin = false;
  
  // Color overlay settings
  String _overlayType = 'image'; // 'image' or 'color'
  Color _backgroundColor = Colors.black;
  String _overlayText = 'Leave the phone';
  Color _textColor = Colors.white;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _overlayText);
    _loadSettings();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('overlay_image');
    
    final hasOverlay = await PlatformChannel.hasOverlayPermission();
    final hasUsageStats = await PlatformChannel.hasUsageStatsPermission();

    final strictMode = prefs.getBool('strict_mode') ?? false;
    final hasPin = await PinService().isPinSet();
    
    // Load color overlay settings
    final overlayType = prefs.getString('overlay_type') ?? 'image';
    final bgColorValue = prefs.getInt('background_color') ?? Colors.black.value;
    final overlayText = prefs.getString('overlay_text') ?? 'Leave the phone';
    final textColorValue = prefs.getInt('text_color') ?? Colors.white.value;

    setState(() {
      _overlayImagePath = imagePath;
      _hasOverlayPermission = hasOverlay;
      _hasUsageStatsPermission = hasUsageStats;
      _isLoading = false;
      _hasPin = hasPin;
      _overlayType = overlayType;
      _backgroundColor = Color(bgColorValue);
      _overlayText = overlayText;
      _textColor = Color(textColorValue);
      _textController.text = overlayText; // Update controller
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

  Future<void> _saveColorOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('overlay_type', _overlayType);
    await prefs.setInt('background_color', _backgroundColor.value);
    await prefs.setString('overlay_text', _overlayText);
    await prefs.setInt('text_color', _textColor.value);
    
    if (_overlayType == 'color') {
      await PlatformChannel.setColorOverlay(
        backgroundColor: _backgroundColor.value,
        text: _overlayText,
        textColor: _textColor.value,
      );
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Color overlay settings saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _pickBackgroundColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Background Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _backgroundColor,
            onColorChanged: (color) {
              setState(() {
                _backgroundColor = color;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ).then((_) => _saveColorOverlay());
  }

  void _pickTextColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Text Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _textColor,
            onColorChanged: (color) {
              setState(() {
                _textColor = color;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ).then((_) => _saveColorOverlay());
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

  Future<void> _setPin() async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PinDialog(
        title: 'Set New PIN',
        isSettingPin: true,
      ),
    );

    if (success == true) {
      _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN set successfully')),
        );
      }
    }
  }

  Future<void> _changePin() async {
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PinDialog(
        title: 'Enter Current PIN',
      ),
    );

    if (verified == true && mounted) {
      _setPin();
    }
  }

  Future<void> _removePin() async {
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PinDialog(
        title: 'Enter Current PIN',
      ),
    );

    if (verified == true) {
      await PinService().removePin();
      _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN removed')),
        );
      }
    }
  }
  
  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will remove all selected apps, overlay settings, and delete any saved images. Continue?',
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
      // Delete the actual image file if it exists
      if (_overlayImagePath != null) {
        try {
          final imageFile = File(_overlayImagePath!);
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        } catch (e) {
          print('Error deleting image file: $e');
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await PlatformChannel.setFocusMode(false);
      await PlatformChannel.setSelectedApps([]);
      await PlatformChannel.setOverlayType('image'); // Reset to default

      setState(() {
        _overlayImagePath = null;
        _overlayType = 'image';
        _backgroundColor = Colors.black;
        _overlayText = 'Leave the phone';
        _textColor = Colors.white;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared and image deleted'),
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
          // Overlay Type Selection
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overlay Type',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'image',
                      label: Text('Image'),
                      icon: Icon(Icons.image),
                    ),
                    ButtonSegment(
                      value: 'color',
                      label: Text('Color'),
                      icon: Icon(Icons.palette),
                    ),
                  ],
                  selected: {_overlayType},
                  onSelectionChanged: (Set<String> selection) async {
                    final newType = selection.first;
                    setState(() {
                      _overlayType = newType;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('overlay_type', _overlayType);
                    
                    if (_overlayType == 'color') {
                      await _saveColorOverlay();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to Color Overlay mode'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      await PlatformChannel.setOverlayType('image');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to Image Overlay mode'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _overlayType == 'image' 
                    ? '📸 Currently using Image mode' 
                    : '🎨 Currently using Color mode',
                  style: TextStyle(
                    color: _overlayType == 'image' ? Colors.blue : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Image Overlay Section
          if (_overlayType == 'image')
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Overlay Image',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Preview
                  if (_overlayImagePath != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(
                      _overlayImagePath == null
                          ? 'Select Custom Image'
                          : 'Change Custom Image',
                    ),
                  ),
                ],
              ),
            ),

          // Color Overlay Section
          if (_overlayType == 'color')
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Color Overlay Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Preview
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Center(
                      child: Text(
                        _overlayText,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Background Color Picker
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    title: const Text('Background Color'),
                    trailing: const Icon(Icons.edit),
                    onTap: _pickBackgroundColor,
                  ),
                  const SizedBox(height: 8),
                  
                  // Text Input
                  TextField(
                    controller: _textController,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'Overlay Text',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Leave the phone',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _overlayText = value;
                      });
                    },
                    onSubmitted: (_) => _saveColorOverlay(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Text Color Picker
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _textColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    title: const Text('Text Color'),
                    trailing: const Icon(Icons.edit),
                    onTap: _pickTextColor,
                  ),
                  const SizedBox(height: 16),
                  
                  // Save Button
                  ElevatedButton.icon(
                    onPressed: _saveColorOverlay,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Color Overlay'),
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

          // Features Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Features',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const ListTile(
                    leading: Icon(Icons.bolt, color: Colors.orange),
                    title: Text('Strict Blocking Active'),
                    subtitle: Text('Apps will be forcefully closed immediately.'),
                ),
              ],
            ),
          ),
          const Divider(),

          // Security Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('PIN Protection'),
                  subtitle: Text(_hasPin 
                    ? 'PIN is set. Required to disable focus or remove apps.'
                    : 'Set a PIN to prevent changes.'
                  ),
                  trailing: _hasPin
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'change') _changePin();
                          if (value == 'remove') _removePin();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'change',
                            child: Text('Change PIN'),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove PIN'),
                          ),
                        ],
                      )
                    : ElevatedButton(
                        onPressed: _setPin,
                        child: const Text('Set PIN'),
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
                  'Focus Overlay helps you stay focused by displaying a custom image or colored background with text when you open distracting apps. Choose between Image mode or Color mode in settings.',
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
