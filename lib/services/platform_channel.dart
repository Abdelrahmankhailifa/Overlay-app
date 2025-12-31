import 'package:flutter/services.dart';

class PlatformChannel {
  static const MethodChannel _channel = MethodChannel('com.example.overlay_app/overlay');

  // Send selected apps to Android
  static Future<void> setSelectedApps(List<String> packageNames) async {
    try {
      await _channel.invokeMethod('setSelectedApps', {
        'packageNames': packageNames,
      });
    } on PlatformException catch (e) {
      print('Error setting selected apps: ${e.message}');
    }
  }

  // Send overlay image path to Android
  static Future<void> setOverlayImage(String imagePath) async {
    try {
      await _channel.invokeMethod('setOverlayImage', {
        'imagePath': imagePath,
      });
    } on PlatformException catch (e) {
      print('Error setting overlay image: ${e.message}');
    }
  }

  // Toggle focus mode on/off
  static Future<void> setFocusMode(bool enabled) async {
    try {
      await _channel.invokeMethod('setFocusMode', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      print('Error setting focus mode: ${e.message}');
    }
  }

  // Request overlay permission
  static Future<bool> requestOverlayPermission() async {
    try {
      final bool result = await _channel.invokeMethod('requestOverlayPermission');
      return result;
    } on PlatformException catch (e) {
      print('Error requesting overlay permission: ${e.message}');
      return false;
    }
  }

  // Request usage stats permission
  static Future<bool> requestUsageStatsPermission() async {
    try {
      final bool result = await _channel.invokeMethod('requestUsageStatsPermission');
      return result;
    } on PlatformException catch (e) {
      print('Error requesting usage stats permission: ${e.message}');
      return false;
    }
  }

  // Check if overlay permission is granted
  static Future<bool> hasOverlayPermission() async {
    try {
      final bool result = await _channel.invokeMethod('hasOverlayPermission');
      return result;
    } on PlatformException catch (e) {
      print('Error checking overlay permission: ${e.message}');
      return false;
    }
  }

  // Check if usage stats permission is granted
  static Future<bool> hasUsageStatsPermission() async {
    try {
      final bool result = await _channel.invokeMethod('hasUsageStatsPermission');
      return result;
    } on PlatformException catch (e) {
      print('Error checking usage stats permission: ${e.message}');
      return false;
    }
  }
}
