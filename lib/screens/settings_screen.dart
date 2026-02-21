import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../services/platform_channel.dart';
import '../services/pin_service.dart';
import '../services/walkthrough_service.dart';
import 'widgets/pin_dialog.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'website_blocker_screen.dart';
import '../utils/walkthrough_keys.dart';

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
  late ScrollController _scrollController;

  bool _hasCheckedWalkthrough = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _overlayText);
    _scrollController = ScrollController();
    _loadSettings();
  }

  Future<void> _checkAndStartWalkthrough(BuildContext context) async {
    if (await WalkthroughService().shouldShowSettingsWalkthrough()) {
       // Check if context is still valid for the operation if needed, 
       // but strictly we rely on the callback being executed.
      if (context.mounted) {
        ShowCaseWidget.of(context).startShowCase([
          WalkthroughKeys.overlayImageSection,
          WalkthroughKeys.permissionsSection,
          WalkthroughKeys.strictModeToggle,
          WalkthroughKeys.changePinButton,
          WalkthroughKeys.dataManagementSection,
          WalkthroughKeys.helpSection,
        ]);
        WalkthroughService().markSettingsWalkthroughComplete();
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ... (keep existing methods: _loadSettings, _pickImage, etc. until build)

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
      _strictModeEnabled = strictMode; // Added missing state update
      _overlayType = overlayType;
      _backgroundColor = Color(bgColorValue);
      _overlayText = overlayText;
      _textColor = Color(textColorValue);
      _textController.text = overlayText; 
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
              backgroundColor: Colors.purple,
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

  Future<void> _sendFeedback() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'breakloop44@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Focus Overlay App Feedback',
        'body': 'Hi, I would like to share some feedback about the app:\n\n',
      }),
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open email client'),
            ),
          );
        }
      }
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error launching email: $e'),
            ),
          );
        }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ShowCaseWidget(
      onStart: (index, key) {
        if (key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
          );
        }
      },
      builder: (context) {
          if (_isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!_hasCheckedWalkthrough) {
            _hasCheckedWalkthrough = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAndStartWalkthrough(context);
            });
          }
          
          return Scaffold(
            appBar: AppBar(
              title: const Text('Settings'),
            ),
            body: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overlay Type Selection Card
                  Showcase(
                    key: WalkthroughKeys.overlayImageSection,
                    title: 'Overlay Appearance',
                    description: 'Customize what you see when an app is blocked.',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.palette_outlined,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Overlay Type',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
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
                                        const SnackBar(
                                          content: Text('Switched to Color Overlay mode'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } else {
                                    await PlatformChannel.setOverlayType('image');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Switched to Image Overlay mode'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: (_overlayType == 'image' ? Colors.blue : Colors.green).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _overlayType == 'image' ? '📸' : '🎨',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _overlayType == 'image' 
                                      ? 'Image mode active' 
                                      : 'Color mode active',
                                    style: TextStyle(
                                      color: _overlayType == 'image' ? Colors.blue[700] : Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Overlay Section
                  if (_overlayType == 'image')
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Custom Image',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            if (_overlayImagePath != null)
                              Column(
                                children: [
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(_overlayImagePath!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.image),
                                label: Text(
                                  _overlayImagePath == null
                                      ? 'Select Custom Image'
                                      : 'Change Custom Image',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Color Overlay Section
                  if (_overlayType == 'color')
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.color_lens_outlined,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Color Settings',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: _backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colorScheme.outlineVariant),
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
                            const SizedBox(height: 20),
                            
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _backgroundColor,
                                    border: Border.all(color: colorScheme.outline),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                title: const Text('Background Color'),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: _pickBackgroundColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                labelText: 'Overlay Text',
                                hintText: 'e.g., Leave the phone',
                                prefixIcon: Icon(Icons.text_fields),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _overlayText = value;
                                });
                              },
                              onSubmitted: (_) => _saveColorOverlay(),
                            ),
                            const SizedBox(height: 12),
                            
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _textColor,
                                    border: Border.all(color: colorScheme.outline),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                title: const Text('Text Color'),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: _pickTextColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveColorOverlay,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Color Settings'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Permissions Card
                  Showcase(
                    key: WalkthroughKeys.permissionsSection,
                    title: 'Required Permissions',
                    description: 'These permissions are vital for the app to function.',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.security_outlined,
                                    color: colorScheme.tertiary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Permissions',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _hasOverlayPermission 
                                    ? Colors.green.withOpacity(0.1)
                                    : colorScheme.errorContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasOverlayPermission 
                                      ? Colors.green.withOpacity(0.3)
                                      : colorScheme.error.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _hasOverlayPermission ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                    color: _hasOverlayPermission ? Colors.green : colorScheme.error,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Display over other apps',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _hasOverlayPermission ? 'Granted' : 'Not granted',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_hasOverlayPermission)
                                    TextButton(
                                      onPressed: _requestOverlayPermission,
                                      child: const Text('Grant'),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _hasUsageStatsPermission 
                                    ? Colors.green.withOpacity(0.1)
                                    : colorScheme.errorContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasUsageStatsPermission 
                                      ? Colors.green.withOpacity(0.3)
                                      : colorScheme.error.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _hasUsageStatsPermission ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                    color: _hasUsageStatsPermission ? Colors.green : colorScheme.error,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Usage access',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _hasUsageStatsPermission ? 'Granted' : 'Not granted',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_hasUsageStatsPermission)
                                    TextButton(
                                      onPressed: _requestUsageStatsPermission,
                                      child: const Text('Grant'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Features Card
                  Showcase(
                    key: WalkthroughKeys.strictModeToggle,
                    title: 'Strict Mode',
                    description: 'Strict Mode immediately closes blocked apps.',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.bolt,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Features',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.bolt, color: Colors.orange),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Strict Blocking Active',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Apps will be forcefully closed immediately',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Security Card
                  Showcase(
                    key: WalkthroughKeys.changePinButton,
                    title: 'PIN Protection',
                    description: 'Secure your settings with a PIN.',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.lock_outlined,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Security',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _hasPin ? Icons.lock : Icons.lock_open_outlined,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PIN Protection',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _hasPin 
                                            ? 'PIN is set and active'
                                            : 'No PIN set',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _hasPin
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
                                    : TextButton(
                                        onPressed: _setPin,
                                        child: const Text('Set PIN'),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Data Management Card
                  Showcase(
                    key: WalkthroughKeys.dataManagementSection,
                    title: 'Data Management',
                    description: 'Clear all settings and data.',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: colorScheme.error,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Data Management',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _clearData,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Clear All Data'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.error,
                                  foregroundColor: colorScheme.onError,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Help Card
                  Showcase(
                    key: WalkthroughKeys.helpSection,
                    title: 'Quick Actions & Help',
                    description: 'Access help and feedback options.',
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.help_outline,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Help',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.help_outline, color: Colors.blue),
                                title: const Text('Show Walkthrough'),
                                subtitle: const Text('Replay the interactive guide'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () async {
                                  if (mounted) {
                                    Navigator.pop(context, 'start_tour');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.feedback_outlined, color: Colors.teal),
                                title: const Text('Send Feedback'),
                                subtitle: const Text('Share your thoughts'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: _sendFeedback,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // About Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'About',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Focus Overlay helps you stay focused by displaying a custom image or colored background with text when you open distracting apps.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
    );
  }
}
