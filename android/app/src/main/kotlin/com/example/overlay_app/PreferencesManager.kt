package com.example.overlay_app

import android.content.Context
import android.content.SharedPreferences

class PreferencesManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS_NAME = "overlay_app_prefs"
        private const val KEY_SELECTED_APPS = "selected_apps"
        private const val KEY_OVERLAY_IMAGE = "overlay_image"
        private const val KEY_FOCUS_MODE = "focus_mode"
    }

    fun setSelectedApps(packageNames: List<String>) {
        prefs.edit().putStringSet(KEY_SELECTED_APPS, packageNames.toSet()).apply()
    }

    fun getSelectedApps(): Set<String> {
        return prefs.getStringSet(KEY_SELECTED_APPS, emptySet()) ?: emptySet()
    }

    fun setOverlayImagePath(path: String) {
        prefs.edit().putString(KEY_OVERLAY_IMAGE, path).apply()
    }

    fun getOverlayImagePath(): String? {
        return prefs.getString(KEY_OVERLAY_IMAGE, null)
    }

    fun setFocusModeEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_FOCUS_MODE, enabled).apply()
    }

    fun isFocusModeEnabled(): Boolean {
        return prefs.getBoolean(KEY_FOCUS_MODE, false)
    }
}
