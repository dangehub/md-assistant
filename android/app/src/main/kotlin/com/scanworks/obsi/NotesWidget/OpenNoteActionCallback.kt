package com.scanworks.obsi

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback

class OpenNoteActionCallback : ActionCallback {
    private val TAG = "OpenNoteActionCallback"

    companion object {
        const val NOTE_FILE_NAME_KEY = "noteFileName"
        const val NOTE_VAULT_NAME_KEY = "vault_name"
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val fileName = parameters[ActionParameters.Key<String>(NOTE_FILE_NAME_KEY)] ?: return
        val vaultName = parameters[ActionParameters.Key<String>(NOTE_VAULT_NAME_KEY)]
        if (vaultName.isNullOrEmpty()) {
            Log.w(TAG, "Vault name parameter is missing, ignoring note tap")
            return
        }

        val uriString = "obsidian://open?vault=$vaultName&file=${fileName}.md"
        Log.d(TAG, "Opening Obsidian note: $uriString")

        val uri = Uri.parse(uriString)
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open Obsidian note", e)
        }
    }
}
