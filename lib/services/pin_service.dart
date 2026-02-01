
import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const String _pinKey = 'user_pin';

  // Singleton pattern
  static final PinService _instance = PinService._internal();
  factory PinService() => _instance;
  PinService._internal();

  /// Checks if a PIN is currently set
  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  /// Verifies the entered PIN against the stored PIN
  Future<bool> verify(String inputPin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    return storedPin == inputPin;
  }

  /// Sets a new PIN
  Future<void> setPin(String newPin) async {
    if (newPin.length != 4) {
      throw ArgumentError('PIN must be 4 digits');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, newPin);
  }

  /// Removes the PIN
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }
}
