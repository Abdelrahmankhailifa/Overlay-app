import 'package:flutter/material.dart';

/// Global keys for showcase targets across different screens
class WalkthroughKeys {
  // Home Screen Keys
  static final GlobalKey focusModeCard = GlobalKey();
  static final GlobalKey focusModeSwitch = GlobalKey();
  static final GlobalKey permissionsCard = GlobalKey();
  static final GlobalKey addAppsButton = GlobalKey();
  static final GlobalKey blockWebsitesButton = GlobalKey();
  static final GlobalKey settingsButton = GlobalKey();
  static final GlobalKey appListItem = GlobalKey();
  static final GlobalKey removeAppButton = GlobalKey();

  // Settings Screen Keys
  static final GlobalKey overlayImageSection = GlobalKey();
  static final GlobalKey galleryPickerButton = GlobalKey();
  static final GlobalKey colorPickerButton = GlobalKey();
  static final GlobalKey resetOverlayButton = GlobalKey();
  static final GlobalKey changePinButton = GlobalKey();
  static final GlobalKey strictModeToggle = GlobalKey();
  static final GlobalKey permissionsSection = GlobalKey();
  static final GlobalKey dataManagementSection = GlobalKey();
  static final GlobalKey helpSection = GlobalKey();

  // App Picker Screen Keys
  static final GlobalKey searchBar = GlobalKey();
  static final GlobalKey appCheckbox = GlobalKey();
  static final GlobalKey saveButton = GlobalKey();

  // Website Blocker Screen Keys
  static final GlobalKey urlInputField = GlobalKey();
  static final GlobalKey addWebsiteButton = GlobalKey();
  static final GlobalKey websiteListItem = GlobalKey();
  static final GlobalKey accessibilityWarning = GlobalKey();
}
