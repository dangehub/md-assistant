package com.dangehub.mdbro

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.RadioButton
import android.widget.RadioGroup

class WidgetConfigureActivity : Activity() {

    companion object {
        private const val PREFS_NAME = "obsi_widget_prefs"
        private const val PREF_PREFIX_KEY = "widget_theme_" // per-widget theme
        private const val PREF_GLOBAL_THEME_KEY = "widget_theme_global" // global theme used by Glance
        const val THEME_LIGHT = "light"
        const val THEME_BLACK = "black"

        fun saveThemePref(context: Context, appWidgetId: Int, theme: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(PREF_PREFIX_KEY + appWidgetId, theme).apply()
        }

        fun loadThemePref(context: Context, appWidgetId: Int, default: String = THEME_LIGHT): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(PREF_PREFIX_KEY + appWidgetId, default) ?: default
        }

        fun saveGlobalTheme(context: Context, theme: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(PREF_GLOBAL_THEME_KEY, theme).apply()
        }

        fun loadGlobalTheme(context: Context, default: String = THEME_LIGHT): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(PREF_GLOBAL_THEME_KEY, default) ?: default
        }
    }

    private var appWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // If the user closes the activity, the widget should not be added.
        setResult(RESULT_CANCELED)

        setContentView(R.layout.widget_configure_activity)

        // Find the widget id from the intent.
        val intent = intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        // If this activity was started with an invalid appWidgetId, finish.
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val themeGroup = findViewById<RadioGroup>(R.id.widget_theme_group)
        val lightRadio = findViewById<RadioButton>(R.id.widget_theme_light)
        val blackRadio = findViewById<RadioButton>(R.id.widget_theme_black)
        val okButton = findViewById<Button>(R.id.widget_config_ok)
        val cancelButton = findViewById<Button>(R.id.widget_config_cancel)

        // Preselect current value if exists
        when (loadThemePref(this, appWidgetId)) {
            THEME_BLACK -> blackRadio.isChecked = true
            else -> lightRadio.isChecked = true
        }

        okButton.setOnClickListener {
            val selectedTheme = when (themeGroup.checkedRadioButtonId) {
                R.id.widget_theme_black -> THEME_BLACK
                else -> THEME_LIGHT
            }

            saveThemePref(this, appWidgetId, selectedTheme)
            saveGlobalTheme(this, selectedTheme)

            // Notify the AppWidgetManager to update the widget
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val intentUpdate = Intent(this, ObsiWidgetReceiver::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            }
            sendBroadcast(intentUpdate)

            val resultValue = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(RESULT_OK, resultValue)
            finish()
        }

        cancelButton.setOnClickListener {
            finish()
        }
    }
}
