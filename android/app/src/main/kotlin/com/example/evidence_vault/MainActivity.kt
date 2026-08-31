package com.example.evidence_vault

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SafDurabilityBridge(applicationContext).register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Persist before Flutter plugins consume the result. Do not match
        // file_picker request codes — file_picker still receives this via super.
        SafDurabilityBridge.onHostActivityResult(this, resultCode, data)
        super.onActivityResult(requestCode, resultCode, data)
    }
}
