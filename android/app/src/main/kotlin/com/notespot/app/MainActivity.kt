package com.notespot.app

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private val pickCode = 7741

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "notespot/picker")
            .setMethodCallHandler { call, result ->
                if (call.method == "pickZip") {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES,
                            arrayOf("application/zip", "application/octet-stream"))
                    }
                    startActivityForResult(intent, pickCode)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickCode) {
            val res = pendingResult
            pendingResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val bytes = contentResolver
                        .openInputStream(data.data!!)?.use { it.readBytes() }
                    res?.success(bytes)
                } catch (e: Exception) {
                    res?.error("READ_FAIL", e.message, null)
                }
            } else {
                res?.success(null)
            }
        }
    }
}