import 'package:shared_preferences/shared_preferences.dart';

class WalkthroughService {
  static const String _walkthroughCompletedKey = 'walkthrough_completed';
  static const String _startWalkthroughKey = 'start_walkthrough';
  static const String _globalWalkthroughStatusKey = 'global_walkthrough_status';

  // Global Status: 'pending', 'later', 'never', 'completed'
  Future<String> getGlobalWalkthroughStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_globalWalkthroughStatusKey) ?? 'pending';
  }

  Future<void> setGlobalWalkthroughStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalWalkthroughStatusKey, status);
  }

  // Force reset all individual walkthroughs so they appear during the tour
  Future<void> resetAllWalkthroughs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeWalkthroughKey, false);
    await prefs.setBool(_settingsWalkthroughKey, false);
    await prefs.setBool(_appPickerWalkthroughKey, false);
    await prefs.setBool(_websiteBlockerWalkthroughKey, false);
    // Ensure legacy keys are also reset if needed
    await prefs.setBool(_walkthroughCompletedKey, false);
  }

  /// Check if walkthrough should be shown
  Future<bool> shouldShowWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    final startWalkthrough = prefs.getBool(_startWalkthroughKey) ?? false;
    final walkthroughCompleted = prefs.getBool(_walkthroughCompletedKey) ?? false;
    
    // Show if start flag is set and not completed yet
    return startWalkthrough && !walkthroughCompleted;
  }

  /// Set flag to start walkthrough (called after tutorial completion)
  Future<void> setStartWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startWalkthroughKey, true);
  }

  /// Mark walkthrough as completed
  Future<void> markWalkthroughComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walkthroughCompletedKey, true);
    await prefs.setBool(_startWalkthroughKey, false);
  }

  /// Reset walkthrough (for manual replay from settings)
  Future<void> resetWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walkthroughCompletedKey, false);
    await prefs.setBool(_startWalkthroughKey, true);
  }

  static const String _homeWalkthroughKey = 'home_walkthrough_completed';
  static const String _settingsWalkthroughKey = 'settings_walkthrough_completed';
  static const String _appPickerWalkthroughKey = 'app_picker_walkthrough_completed';
  static const String _websiteBlockerWalkthroughKey = 'website_blocker_walkthrough_completed';

  /// Check if walkthrough has been completed at least once
  Future<bool> isWalkthroughCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_walkthroughCompletedKey) ?? false;
  }

  // Home Walkthrough
  Future<bool> shouldShowHomeWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_homeWalkthroughKey) ?? false);
  }

  Future<void> markHomeWalkthroughComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeWalkthroughKey, true);
  }

  // Settings Walkthrough
  Future<bool> shouldShowSettingsWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_settingsWalkthroughKey) ?? false);
  }

  Future<void> markSettingsWalkthroughComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_settingsWalkthroughKey, true);
  }

  // App Picker Walkthrough
  Future<bool> shouldShowAppPickerWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_appPickerWalkthroughKey) ?? false);
  }

  Future<void> markAppPickerWalkthroughComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appPickerWalkthroughKey, true);
  }

  // Website Blocker Walkthrough
  Future<bool> shouldShowWebsiteBlockerWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_websiteBlockerWalkthroughKey) ?? false);
  }

  Future<void> markWebsiteBlockerWalkthroughComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_websiteBlockerWalkthroughKey, true);
  }
}
