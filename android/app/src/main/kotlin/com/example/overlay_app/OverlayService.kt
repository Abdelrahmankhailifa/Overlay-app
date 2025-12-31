package com.example.overlay_app

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.LayoutInflater
import android.view.WindowManager
import android.widget.ImageView
import android.widget.FrameLayout
import java.io.File

class OverlayService(private val context: Context) {
    private var windowManager: WindowManager? = null
    private var overlayView: FrameLayout? = null
    private var isOverlayShowing = false

    fun showOverlay(imagePath: String) {
        if (isOverlayShowing) return

        val imageFile = File(imagePath)
        if (!imageFile.exists()) {
            showDefaultOverlay()
            return
        }

        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Create overlay view
        overlayView = FrameLayout(context).apply {
            setBackgroundColor(0xFF000000.toInt()) // Black background
        }

        val bitmap = BitmapFactory.decodeFile(imagePath)
        val imageView = ImageView(context).apply {
            setImageBitmap(bitmap)
            scaleType = ImageView.ScaleType.FIT_CENTER
        }
        overlayView?.addView(imageView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        addOverlayView()
    }

    fun showDefaultOverlay() {
        if (isOverlayShowing) return

        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Create overlay view with message
        overlayView = FrameLayout(context).apply {
            setBackgroundColor(0xCC000000.toInt()) // Semi-transparent black
        }

        val textView = android.widget.TextView(context).apply {
            text = "Focus Mode Active"
            textSize = 24f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
        }
        
        overlayView?.addView(textView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        ))

        addOverlayView()
    }

    private fun addOverlayView() {
        // Set up window parameters
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager?.addView(overlayView, params)
            isOverlayShowing = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun hideOverlay() {
        if (!isOverlayShowing) return

        try {
            overlayView?.let {
                windowManager?.removeView(it)
            }
            overlayView = null
            isOverlayShowing = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
