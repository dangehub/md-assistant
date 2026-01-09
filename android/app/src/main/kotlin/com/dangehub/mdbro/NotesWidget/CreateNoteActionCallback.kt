package com.dangehub.mdbro

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class CreateNoteActionCallback : ActionCallback {
    private val TAG = "CreateNoteActionCallback"

    companion object {
        const val NOTE_VAULT_NAME_KEY = "vault_name"
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val vaultName = parameters[ActionParameters.Key<String>(NOTE_VAULT_NAME_KEY)]
        if (vaultName.isNullOrEmpty()) {
            Log.w(TAG, "Vault name parameter is missing, cannot create note")
            return
        }

        val formatter = SimpleDateFormat("yyyy-MM-dd_HH-mm", Locale.US)
        val timestamp = formatter.format(Date())
        val fileName = "$timestamp"

        val uriString = "obsidian://new?vault=$vaultName&file=${fileName}.md"
        Log.d(TAG, "Creating Obsidian note: $uriString")

        val uri = Uri.parse(uriString)
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create Obsidian note", e)
        }
    }
}
