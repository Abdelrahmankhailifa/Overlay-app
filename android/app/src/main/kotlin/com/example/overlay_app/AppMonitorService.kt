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
import androidx.core.app.NotificationCompat

class AppMonitorService : Service() {
    private lateinit var preferencesManager: PreferencesManager
    private lateinit var overlayService: OverlayService
    private val handler = Handler(Looper.getMainLooper())
    private var isMonitoring = false
    private var currentForegroundApp: String? = null

    companion object {
        private const val CHANNEL_ID = "overlay_monitor_channel"
        private const val NOTIFICATION_ID = 1
        private const val CHECK_INTERVAL = 1000L // Check every 1 second
    }

    override fun onCreate() {
        super.onCreate()
        preferencesManager = PreferencesManager(this)
        overlayService = OverlayService(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())
        startMonitoring()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        overlayService.hideOverlay()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Focus Mode Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors foreground apps for focus mode"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus Mode Active")
            .setContentText("Monitoring selected apps")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startMonitoring() {
        isMonitoring = true
        handler.post(monitorRunnable)
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
        val foregroundApp = getForegroundApp() ?: return
        
        if (foregroundApp != currentForegroundApp) {
            currentForegroundApp = foregroundApp
            
            val selectedApps = preferencesManager.getSelectedApps()
            val shouldShowOverlay = selectedApps.contains(foregroundApp)
            
            if (shouldShowOverlay) {
                val imagePath = preferencesManager.getOverlayImagePath()
                if (imagePath != null) {
                    overlayService.showOverlay(imagePath)
                } else {
                    overlayService.showDefaultOverlay()
                }
            } else {
                overlayService.hideOverlay()
            }
        }
    }

    private fun getForegroundApp(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val currentTime = System.currentTimeMillis()
        
        // Query events from the last 2 seconds
        val usageEvents = usageStatsManager.queryEvents(currentTime - 2000, currentTime)
        val event = UsageEvents.Event()
        
        var foregroundApp: String? = null
        
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                foregroundApp = event.packageName
            }
        }
        
        return foregroundApp
    }
}
