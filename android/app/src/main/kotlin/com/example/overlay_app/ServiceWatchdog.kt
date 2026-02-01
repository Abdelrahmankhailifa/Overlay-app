package com.example.overlay_app

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class ServiceWatchdog : BroadcastReceiver() {
    
    companion object {
        const val ACTION_WATCHDOG_TICK = "com.example.overlay_app.WATCHDOG_TICK"
        private const val TAG = "ServiceWatchdog"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Watchdog received action: $action")
        
        val preferencesManager = PreferencesManager(context)
        
        // Only restart if focus mode is actually supposed to be enabled
        if (preferencesManager.isFocusModeEnabled()) {
            ensureServiceIsRunning(context)
        }
    }

    private fun ensureServiceIsRunning(context: Context) {
        if (!isServiceRunning(context, AppMonitorService::class.java)) {
            Log.d(TAG, "Service not running, restarting...")
            val serviceIntent = Intent(context, AppMonitorService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start service: ${e.message}")
            }
        } else {
            Log.d(TAG, "Service is already running")
        }
    }

    private fun isServiceRunning(context: Context, serviceClass: Class<*>): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
