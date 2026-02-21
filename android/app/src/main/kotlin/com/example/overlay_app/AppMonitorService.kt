package com.example.overlay_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import android.content.SharedPreferences
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.SystemClock
import android.util.Log

class AppMonitorService : Service() {
    private lateinit var preferencesManager: PreferencesManager
    
    companion object {
        private const val CHANNEL_ID = "overlay_monitor_channel"
        private const val NOTIFICATION_ID = 1
        private const val CHECK_INTERVAL = 2000L // Check every 2 seconds (Battery friendly fallback)
    }
    
    // Config values that can change
    private var selectedApps: Set<String> = emptySet()
    
    // Fallback polling machinery
    private val handler = Handler(Looper.getMainLooper())
    private var isMonitoring = false
    private var currentForegroundApp: String? = null
    private lateinit var overlayService: OverlayService

    override fun onCreate() {
        super.onCreate()
        preferencesManager = PreferencesManager(this)
        overlayService = OverlayService(this)
        
        // Initial load
        selectedApps = preferencesManager.getSelectedApps()
        
        // Register for changes
        preferencesManager.registerListener(preferenceListener)
        
        createNotificationChannel()
        scheduleWatchdog()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Just start foreground to keep process alive.
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Start polling as backup
        startMonitoring()
        
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        preferencesManager.unregisterListener(preferenceListener)
    }
    
    private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        when (key) {
            PreferencesManager.KEY_FOCUS_MODE -> {
                if (!preferencesManager.isFocusModeEnabled()) {
                    // Focus mode was turned off — hide overlay immediately and shut down
                    overlayService.hideOverlay()
                    stopSelf()
                }
            }
            PreferencesManager.KEY_SELECTED_APPS -> {
                selectedApps = preferencesManager.getSelectedApps()
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
    
    private fun startMonitoring() {
        if (!isMonitoring) {
            isMonitoring = true
            handler.post(monitorRunnable)
        }
    }

    private fun stopMonitoring() {
        isMonitoring = false
        handler.removeCallbacks(monitorRunnable)
    }

    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (isMonitoring) {
                checkForegroundApp()
                handler.postDelayed(this, CHECK_INTERVAL)
            }
        }
    }

    private fun checkForegroundApp() {
        // If focus mode is disabled, hide any lingering overlay and do nothing
        if (!preferencesManager.isFocusModeEnabled()) {
            overlayService.hideOverlay()
            return
        }

        val foregroundApp = getForegroundApp() ?: return
        
        // Browser packages - we don't block browsers here, WebsiteMonitorService handles URL blocking
        val browserPackages = setOf(
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
        
        if (foregroundApp != currentForegroundApp) {
            currentForegroundApp = foregroundApp
            
            // Only check if app is directly blocked
            val isAppBlocked = selectedApps.contains(foregroundApp)
            
            if (isAppBlocked) {
                 // Show overlay and force close for blocked apps
                 overlayService.showOverlay()
                 performHomeAction()
            } else {
                // Initiating switch AWAY from blocked app
                // Hide overlay for non-browser apps (browsers are handled by WebsiteMonitorService)
                if (!browserPackages.contains(foregroundApp)) {
                    overlayService.hideOverlay()
                }
            }
        } else {
            // Even if app didn't change, if we are currently stuck in a blocked app, kick them out
             if (selectedApps.contains(foregroundApp)) {
                 performHomeAction()
             }
        }
    }

    private fun performHomeAction() {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun getForegroundApp(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val currentTime = System.currentTimeMillis()
        val usageEvents = usageStatsManager.queryEvents(currentTime - 5000, currentTime) // Look back 5s
        val event = UsageEvents.Event()
        
        var foregroundApp: String? = null
        var lastTime: Long = 0
        
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                if (event.timeStamp > lastTime) {
                    foregroundApp = event.packageName
                    lastTime = event.timeStamp
                }
            }
        }
        return foregroundApp
    }
    
    // Check if the service is removed from the Task List (Swiped away)
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d("AppMonitorService", "Task removed, scheduling restart")
        
        // Ensure we restart if possible
        val restartServiceIntent = Intent(applicationContext, ServiceWatchdog::class.java).apply {
            action = ServiceWatchdog.ACTION_WATCHDOG_TICK
        }
        
        val restartServicePendingIntent = PendingIntent.getBroadcast(
            applicationContext, 2, restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmService = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmService.set(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + 1000,
            restartServicePendingIntent
        )
    }

    private fun scheduleWatchdog() {
        val intent = Intent(this, ServiceWatchdog::class.java).apply {
            action = ServiceWatchdog.ACTION_WATCHDOG_TICK
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, 123, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Schedule every 5 minutes
        alarmManager.setInexactRepeating(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + 5 * 60 * 1000,
            5 * 60 * 1000,
            pendingIntent
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Focus Mode Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Focus Mode active"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus Mode Active")
            .setContentText("Monitoring in background")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true) // Make it harder to dismiss
            .build()
    }
}
