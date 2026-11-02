package com.finance.spendo

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.finance.spendo/deeplink"
    private val shareChannelName = "com.finance.spendo/share"
    private var methodChannel: MethodChannel? = null
    private var shareChannel: MethodChannel? = null
    private var initialLink: String? = null
    private var initialSharedFilePath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, isInitial = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialLink") {
                result.success(initialLink)
                initialLink = null
            } else {
                result.notImplemented()
            }
        }

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
        shareChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialSharedFile") {
                result.success(initialSharedFilePath)
                initialSharedFilePath = null
            } else if (call.method == "extractImageText") {
                val path = call.arguments as? String
                if (path != null && File(path).exists()) {
                    try {
                        val file = File(path)
                        val image = InputImage.fromFilePath(this, Uri.fromFile(file))
                        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                        recognizer.process(image)
                            .addOnSuccessListener { visionText ->
                                result.success(visionText.text)
                            }
                            .addOnFailureListener {
                                result.success("")
                            }
                    } catch (_: Exception) {
                        result.success("")
                    }
                } else {
                    result.success("")
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, isInitial = false)
    }

    private fun handleIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return

        val data = intent.dataString
        if (!data.isNullOrEmpty() && data.startsWith("spendo://")) {
            if (isInitial && methodChannel == null) {
                initialLink = data
            } else {
                methodChannel?.invokeMethod("onDeepLink", data)
            }
            return
        }

        val action = intent.action
        val type = intent.type ?: ""
        var sharedUri: Uri? = null

        if (Intent.ACTION_SEND == action) {
            sharedUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        } else if (Intent.ACTION_VIEW == action && type.contains("pdf")) {
            sharedUri = intent.data
        }

        if (sharedUri != null) {
            val savedPath = copyUriToCache(sharedUri, type)
            if (savedPath != null) {
                if (isInitial && shareChannel == null) {
                    initialSharedFilePath = savedPath
                } else {
                    shareChannel?.invokeMethod("onSharedFile", savedPath)
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri, mimeType: String): String? {
        return try {
            val ext = if (mimeType.contains("pdf") || uri.toString().lowercase().endsWith(".pdf")) {
                ".pdf"
            } else {
                ".jpg"
            }
            val outFile = File(cacheDir, "shared_yellow_invoice_${System.currentTimeMillis()}$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            }
            outFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }
}
