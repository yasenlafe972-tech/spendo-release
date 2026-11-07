package com.finance.spendo

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
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

    companion object {
        private var activeChannel: MethodChannel? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        fun deliverLiveWalletNotification(payloadJson: String): Boolean {
            val channel = activeChannel ?: return false
            mainHandler.post {
                try {
                    channel.invokeMethod("onWalletNotification", payloadJson)
                } catch (_: Exception) {
                }
            }
            return true
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, isInitial = true)
    }

    override fun onDestroy() {
        if (activeChannel == methodChannel) {
            activeChannel = null
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        activeChannel = methodChannel

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(initialLink)
                    initialLink = null
                }
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationListenerSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "getPendingWalletNotifications" -> {
                    val prefs = applicationContext.getSharedPreferences(
                        SpendoWalletNotificationListener.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    val raw = prefs.getString(SpendoWalletNotificationListener.KEY_PENDING, "[]") ?: "[]"
                    prefs.edit().putString(SpendoWalletNotificationListener.KEY_PENDING, "[]").apply()
                    result.success(raw)
                }
                "openWalletApp" -> {
                    result.success(launchWalletOnDevice())
                }
                else -> result.notImplemented()
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

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && cn.packageName == pkgName) {
                    return true
                }
            }
        }
        return false
    }

    private fun launchWalletOnDevice(): Boolean {
        val walletPackages = listOf(
            "com.google.android.apps.walletnfcrel",
            "com.samsung.android.spay",
            "com.samsung.android.spaymini"
        )
        for (pkg in walletPackages) {
            val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
                return true
            }
        }
        return try {
            val playStoreIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://wallet.google.com")
            )
            playStoreIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(playStoreIntent)
            true
        } catch (_: Exception) {
            false
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
