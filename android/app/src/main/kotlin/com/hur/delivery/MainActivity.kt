package com.hur.delivery

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Enable edge-to-edge display for backward compatibility with Android 15+
        // This ensures consistent behavior across all Android versions
        // Android 15+ apps targeting SDK 35 display edge-to-edge by default
        // This call ensures backward compatibility for older Android versions
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
