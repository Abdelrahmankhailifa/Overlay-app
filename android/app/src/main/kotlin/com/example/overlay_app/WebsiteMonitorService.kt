package com.example.overlay_app

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.content.Intent
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.Log
import android.content.SharedPreferences

class WebsiteMonitorService : AccessibilityService() {
    private lateinit var preferencesManager: PreferencesManager
    private lateinit var overlayService: OverlayService
    private var blockedApps: Set<String> = emptySet()
    private var blockedWebsites: Set<String> = emptySet()
    
    // Common package names for browsers
    private val browserPackages = setOf(
        "com.android.chrome",
        "com.google.android.apps.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "com.chrome.canary",
        "org.mozilla.firefox",
        "com.sec.android.app.sbrowser",
        "com.microsoft.emmx",
        "com.opera.browser",
        "com.opera.mini.native"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        preferencesManager = PreferencesManager(this)
        overlayService = OverlayService(this)
        
        // Initial load
        blockedApps = preferencesManager.getSelectedApps()
        blockedWebsites = preferencesManager.getBlockedWebsites()
        
        // Register for changes
        preferencesManager.registerListener(preferenceListener)
        
        Log.d("WebsiteMonitorService", "Service connected")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::preferencesManager.isInitialized) {
            preferencesManager.unregisterListener(preferenceListener)
        }
    }

    private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        when (key) {
            PreferencesManager.KEY_SELECTED_APPS -> {
                blockedApps = preferencesManager.getSelectedApps()
            }
            PreferencesManager.KEY_BLOCKED_WEBSITES -> {
                blockedWebsites = preferencesManager.getBlockedWebsites()
            }
            PreferencesManager.KEY_OVERLAY_TYPE,
            PreferencesManager.KEY_OVERLAY_IMAGE,
            PreferencesManager.KEY_BACKGROUND_COLOR,
            PreferencesManager.KEY_OVERLAY_TEXT,
            PreferencesManager.KEY_TEXT_COLOR -> {
                // If overlay is currently showing, we need to refresh it
                if (overlayService.isVisible()) {
                    overlayService.hideOverlay()
                    overlayService.showOverlay()
                }
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        val eventType = event.eventType

        // Periodic watchdog check inside accessibility events
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            ensureAppMonitorRunning()
        }

        // 1. Check if the APP itself is blocked
        if (blockedApps.contains(packageName)) {
            Log.d("WebsiteMonitorService", "BLOCKED APP DETECTED: $packageName")
            blockApp()
            return 
        }

        // 2. Logic for Browsers (Content Change or State Change)
        if (browserPackages.contains(packageName)) {
            Log.d("WebsiteMonitorService", "Browser detected: $packageName, Event: $eventType")
            handleBrowserContent()
            return
        }

        // 3. Logic for Regular Apps (Hiding the overlay)
        // CRITICAL: Only hide if we explicitly switched to a new window (STATE_CHANGED).
        // Ignoring CONTENT_CHANGED prevents SystemUI (notifications, clock) or Keyboard from hiding the overlay.
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // It's a regular app, not blocked, not a browser.
            // Safe to hide.
            overlayService.hideOverlay()
        }
    }

    private fun blockApp() {
        // Show Overlay
        overlayService.showOverlay()
        
        // Go Home
        performHomeAction()
    }

    private fun performHomeAction() {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun ensureAppMonitorRunning() {
        if (preferencesManager.isFocusModeEnabled() && !isServiceRunning(AppMonitorService::class.java)) {
            Log.d("WebsiteMonitorService", "AppMonitorService not running, starting from AccessibilityService")
            val serviceIntent = Intent(this, AppMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        }
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun scanWindowForBlockedContent(node: AccessibilityNodeInfo, blockedSites: Set<String>): Boolean {
        if (blockedSites.isEmpty()) return false

        // 1. Check current node text
        if (node.text != null) {
            val text = node.text.toString().lowercase()
            for (site in blockedSites) {
                // Check if the text contains the site domain
                // We add simple boundaries to avoid blocking "facebook-news.com" if you only blocked "book.com"
                if (text.contains(site.lowercase())) {
                    Log.d("WebsiteMonitorService", "BLOCKING DETECTED: Found '$site' in text: '$text'")
                    return true
                }
            }
        }

        // 2. Check Input Text (URL bars often have this)
        // If it's an editable text field, it's likely the URL bar or search bar
        if (node.isEditable && node.text != null) {
             val text = node.text.toString().lowercase()
             for (site in blockedSites) {
                if (text.contains(site.lowercase())) {
                    Log.d("WebsiteMonitorService", "BLOCKING URL BAR: Found '$site' in editable text: '$text'")
                    return true
                }
            }
        }

        // 3. Recurse children
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                if (scanWindowForBlockedContent(child, blockedSites)) {
                    child.recycle()
                    return true
                }
                child.recycle()
            }
        }
        return false
    }

    private fun handleBrowserContent() {
         if (blockedWebsites.isEmpty()) return

         val rootNode = rootInActiveWindow ?: return
         
         if (scanWindowForBlockedContent(rootNode, blockedWebsites)) {
             // Block detected!
             overlayService.showOverlay()
             performHomeAction()
         } else {
             // Safe
             overlayService.hideOverlay()
         }
    }
    
    // Helper to print all nodes for debugging
    private fun logNodeHierarchy(node: AccessibilityNodeInfo, depth: Int) {
        // Log.d("WebsiteMonitorService", "  ".repeat(depth) + "Node: ${node.viewIdResourceName} Text: ${node.text}")
        // for (i in 0 until node.childCount) {
        //    node.getChild(i)?.let { logNodeHierarchy(it, depth + 1) }
        // }
    }
    
    private fun cleanUrl(url: String): String {
        return url.replace("http://", "")
                  .replace("https://", "")
                  .replace("www.", "")
    }

    override fun onInterrupt() {
        Log.d("WebsiteMonitorService", "Service interrupted")
    }
}
