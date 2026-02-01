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
      // Also set overlay type to image
      await setOverlayType('image');
    } on PlatformException catch (e) {
      print('Error setting overlay image: ${e.message}');
    }
  }

  // Send color overlay settings to Android
  static Future<void> setColorOverlay({
    required int backgroundColor,
    required String text,
    required int textColor,
  }) async {
    try {
      await _channel.invokeMethod('setColorOverlay', {
        'backgroundColor': backgroundColor,
        'text': text,
        'textColor': textColor,
      });
    } on PlatformException catch (e) {
      print('Error setting color overlay: ${e.message}');
    }
  }

  // Set overlay type (image or color)
  static Future<void> setOverlayType(String type) async {
    try {
      await _channel.invokeMethod('setOverlayType', {
        'type': type,
      });
    } on PlatformException catch (e) {
      print('Error setting overlay type: ${e.message}');
    }
  }

  // Set image source (custom or default)
  static Future<void> setImageSource(String source) async {
    try {
      await _channel.invokeMethod('setImageSource', {
        'source': source,
      });
    } on PlatformException catch (e) {
      print('Error setting image source: ${e.message}');
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

  // Send blocked websites to Android
  static Future<void> setBlockedWebsites(List<String> websites) async {
    try {
      await _channel.invokeMethod('setBlockedWebsites', {
        'websites': websites,
      });
    } on PlatformException catch (e) {
      print('Error setting blocked websites: ${e.message}');
    }
  }

  // Request accessibility permission
  static Future<bool> requestAccessibilityPermission() async {
    try {
      final bool result = await _channel.invokeMethod('requestAccessibilityPermission');
      return result;
    } on PlatformException catch (e) {
      print('Error requesting accessibility permission: ${e.message}');
      return false;
    }
  }

  // Check if accessibility permission is granted
  static Future<bool> hasAccessibilityPermission() async {
    try {
      final bool result = await _channel.invokeMethod('isAccessibilityGranted');
      return result;
    } on PlatformException catch (e) {
      print('Error checking accessibility permission: ${e.message}');
      return false;
    }
  }

  // Check if battery optimization is ignored
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool result = await _channel.invokeMethod('isBatteryOptimizationIgnored');
      return result;
    } on PlatformException catch (e) {
      print('Error checking battery optimization: ${e.message}');
      return true; // Default to true to not annoy user on error
    }
  }

  // Request battery optimization ignore
  static Future<bool> requestBatteryOptimization() async {
    try {
      final bool result = await _channel.invokeMethod('requestBatteryOptimization');
      return result;
    } on PlatformException catch (e) {
      print('Error requesting battery optimization: ${e.message}');
      return false;
    }
  }
}
