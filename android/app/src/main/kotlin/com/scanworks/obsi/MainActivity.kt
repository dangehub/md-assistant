package com.scanworks.obsi

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val INTENT_CHANNEL = "intent_handler"
    private var intentChannel: MethodChannel? = null
    private var pendingIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        intentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
        intentChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialIntent" -> {
                    val intentData = getIntentData(intent)
                    result.success(intentData)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingIntent = intent
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val intentData = getIntentData(intent)
        if (intentData != null) {
            intentChannel?.invokeMethod("onNewIntent", intentData)
        }
    }

    private fun getIntentData(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        
        val action = intent.getStringExtra("action")
        if (action.isNullOrEmpty()) return null
        
        val extras = mutableMapOf<String, Any?>()
        intent.extras?.let { bundle ->
            for (key in bundle.keySet()) {
                extras[key] = bundle.get(key)
            }
        }
        
        return mapOf(
            "action" to action,
            "extras" to extras
        )
    }
}
