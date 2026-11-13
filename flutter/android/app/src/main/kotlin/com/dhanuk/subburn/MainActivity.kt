package com.dhanuk.subburn

import android.app.ActivityManager
import android.graphics.BitmapFactory
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * FlutterActivity does not set a task description, so Android's recents
 * (task switcher) falls back to the icon captured when the task was *created*.
 * That snapshot survives app updates: a device that ran an early build kept
 * showing the framework's default mark in recents long after the real icon
 * shipped.
 *
 * Setting the description explicitly on every start and resume removes the
 * ambiguity — the recents header always renders SubBurn's own artwork, and
 * refreshing on resume also repairs a task that was created by an older
 * install.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyTaskDescription()
    }

    override fun onResume() {
        super.onResume()
        applyTaskDescription()
    }

    @Suppress("DEPRECATION")
    private fun applyTaskDescription() {
        val label = getString(R.string.app_name)
        val background = getColor(R.color.sb_launch_background)
        // A dedicated bitmap: mipmap/ic_launcher is an adaptive-icon XML on
        // API 26+, which BitmapFactory cannot decode (it would return null and
        // leave the header iconless).
        val bitmap = BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher_task)
        setTaskDescription(
            ActivityManager.TaskDescription(label, bitmap, background),
        )
    }
}
