package com.scanworks.obsi

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import com.scanworks.obsi.NotesWidget.Companion.NOTES_JSON_KEY
import com.scanworks.obsi.NotesWidget.Companion.NOTES_VAULT_DIR_KEY
import com.scanworks.obsi.NotesWidget.Companion.NOTES_VAULT_KEY
import org.json.JSONArray
import java.io.File

class RefreshBookmarksActionCallback : ActionCallback {
    private val TAG = "RefreshBookmarksActionCallback"

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        try {
            updateAppWidgetState(context, HomeWidgetGlanceStateDefinition(), glanceId) { state: HomeWidgetGlanceState ->
                val prefs = state.preferences
                val vaultName = prefs.getString(NOTES_VAULT_KEY, null)
                val vaultDir = prefs.getString(NOTES_VAULT_DIR_KEY, null)
                Log.w(TAG, "Vault name: $vaultName")
                Log.w(TAG, "Vault directory: $vaultDir")
                if (vaultName.isNullOrEmpty() || vaultDir.isNullOrEmpty()) {
                    Log.w(TAG, "Vault name or directory is missing; cannot refresh bookmarks")
                    return@updateAppWidgetState state
                }

                val bookmarksFile = BookmarksRefreshHelper.findBookmarksFile(vaultDir)
                if (bookmarksFile == null) {
                    Log.w(TAG, "Bookmarks file not found in directory tree")
                    return@updateAppWidgetState state
                }
                Log.w(TAG, "Using bookmarks file: ${bookmarksFile.absolutePath}")

                val existingJson = prefs.getString(NOTES_JSON_KEY, null)
                val updatedJson = BookmarksRefreshHelper.refreshBookmarks(bookmarksFile, existingJson)
                
                prefs.edit()
                    .putString(NOTES_JSON_KEY, updatedJson)
                    .apply()

                state
            }

            NotesWidget().update(context, glanceId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to refresh bookmarks", e)
        }
    }
}
