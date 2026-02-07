package com.example.BreakLoop

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.BreakLoop/overlay"
    private lateinit var preferencesManager: PreferencesManager

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Prevent peeking in Recents
        window.setFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE, android.view.WindowManager.LayoutParams.FLAG_SECURE)
        
        preferencesManager = PreferencesManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSelectedApps" -> {
                    val packageNames = call.argument<List<String>>("packageNames")
                    if (packageNames != null) {
                        preferencesManager.setSelectedApps(packageNames)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package names cannot be null", null)
                    }
                }
                "setOverlayImage" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath != null) {
                        preferencesManager.setOverlayImagePath(imagePath)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Image path cannot be null", null)
                    }
                }
                "setFocusMode" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled != null) {
                        preferencesManager.setFocusModeEnabled(enabled)
                        if (enabled) {
                            startMonitoringService()
                            // Auto-request battery optimization if not ignored
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                    intent.data = Uri.parse("package:$packageName")
                                    startActivity(intent)
                                }
                            }
                        } else {
                            stopMonitoringService()
                        }
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Enabled cannot be null", null)
                    }
                }

                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "requestUsageStatsPermission" -> {
                    if (!hasUsageStatsPermission()) {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        startActivity(intent)
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "hasOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "setBlockedWebsites" -> {
                    val websites = call.argument<List<String>>("websites")
                    if (websites != null) {
                        preferencesManager.setBlockedWebsites(websites)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Websites list cannot be null", null)
                    }
                }
                "requestAccessibilityPermission" -> {
                    if (!isAccessibilityServiceEnabled()) {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        startActivity(intent)
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "isAccessibilityGranted" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "requestBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent()
                        val packageName = packageName
                        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "isBatteryOptimizationIgnored" -> {
                     if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val packageName = packageName
                        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "setOverlayType" -> {
                    val type = call.argument<String>("type")
                    if (type != null) {
                        preferencesManager.setOverlayType(type)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Overlay type cannot be null", null)
                    }
                }
                "setImageSource" -> {
                    val source = call.argument<String>("source")
                    if (source != null) {
                        preferencesManager.setImageSource(source)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Image source cannot be null", null)
                    }
                }
                "setColorOverlay" -> {
                    val backgroundColor = (call.argument<Any>("backgroundColor") as? Long)?.toInt() 
                        ?: (call.argument<Any>("backgroundColor") as? Int)
                    val text = call.argument<String>("text")
                    val textColor = (call.argument<Any>("textColor") as? Long)?.toInt() 
                        ?: (call.argument<Any>("textColor") as? Int)
                    
                    if (backgroundColor != null && text != null && textColor != null) {
                        preferencesManager.setOverlayType("color")
                        preferencesManager.setBackgroundColor(backgroundColor)
                        preferencesManager.setOverlayText(text)
                        preferencesManager.setTextColor(textColor)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Color overlay parameters cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityEnabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED, 0
        )
        if (accessibilityEnabled == 1) {
            val service = "$packageName/${WebsiteMonitorService::class.java.canonicalName}"
            val settingValue = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            if (settingValue != null) {
                return settingValue.contains(service)
            }
        }
        return false
    }

    private fun startMonitoringService() {
        val intent = Intent(this, AppMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMonitoringService() {
        val intent = Intent(this, AppMonitorService::class.java)
        stopService(intent)
    }
}
