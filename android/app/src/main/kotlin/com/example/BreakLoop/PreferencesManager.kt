package com.example.BreakLoop

import android.content.Context
import android.content.SharedPreferences

class PreferencesManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        const val PREFS_NAME = "BreakLoop_prefs"
        const val KEY_SELECTED_APPS = "selected_apps"
        const val KEY_OVERLAY_IMAGE = "overlay_image"
        const val KEY_FOCUS_MODE = "focus_mode"
        const val KEY_BLOCKED_WEBSITES = "blocked_websites"
        const val KEY_STRICT_MODE = "strict_mode"
        const val KEY_OVERLAY_TYPE = "overlay_type"
        const val KEY_BACKGROUND_COLOR = "background_color"
        const val KEY_OVERLAY_TEXT = "overlay_text"
        const val KEY_TEXT_COLOR = "text_color"
        const val KEY_IMAGE_SOURCE = "image_source"
    }

    fun registerListener(listener: SharedPreferences.OnSharedPreferenceChangeListener) {
        prefs.registerOnSharedPreferenceChangeListener(listener)
    }

    fun unregisterListener(listener: SharedPreferences.OnSharedPreferenceChangeListener) {
        prefs.unregisterOnSharedPreferenceChangeListener(listener)
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

    fun setBlockedWebsites(websites: List<String>) {
        prefs.edit().putStringSet(KEY_BLOCKED_WEBSITES, websites.toSet()).apply()
    }

    fun getBlockedWebsites(): Set<String> {
        return prefs.getStringSet(KEY_BLOCKED_WEBSITES, emptySet()) ?: emptySet()
    }

    fun setStrictModeEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_STRICT_MODE, enabled).apply()
    }

    fun isStrictModeEnabled(): Boolean {
        return prefs.getBoolean(KEY_STRICT_MODE, false)
    }

    fun setOverlayType(type: String) {
        prefs.edit().putString(KEY_OVERLAY_TYPE, type).apply()
    }

    fun getOverlayType(): String {
        return prefs.getString(KEY_OVERLAY_TYPE, "image") ?: "image"
    }

    fun setBackgroundColor(color: Int) {
        prefs.edit().putInt(KEY_BACKGROUND_COLOR, color).apply()
    }

    fun getBackgroundColor(): Int {
        return prefs.getInt(KEY_BACKGROUND_COLOR, 0xFF000000.toInt())
    }

    fun setOverlayText(text: String) {
        prefs.edit().putString(KEY_OVERLAY_TEXT, text).apply()
    }

    fun getOverlayText(): String {
        return prefs.getString(KEY_OVERLAY_TEXT, "Focus Mode Active") ?: "Focus Mode Active"
    }

    fun setTextColor(color: Int) {
        prefs.edit().putInt(KEY_TEXT_COLOR, color).apply()
    }

    fun getTextColor(): Int {
        return prefs.getInt(KEY_TEXT_COLOR, 0xFFFFFFFF.toInt())
    }

    fun setImageSource(source: String) {
        prefs.edit().putString(KEY_IMAGE_SOURCE, source).apply()
    }

    fun getImageSource(): String {
        return prefs.getString(KEY_IMAGE_SOURCE, "custom") ?: "custom"
    }
}
