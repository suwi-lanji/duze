package com.codenamegoon.duze

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, // Correct parameter
            "example", // Factory ID, match with Flutter
            NativeAdFactoryExample(layoutInflater)
        )
    }

    override fun cleanUpFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "example")
        super.cleanUpFlutterEngine(flutterEngine) // Correct super call
    }
}