package com.dangehub.mdbro

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback

/**
 * Callback triggered when the user taps the + button on the Memos widget.
 * Launches MemoInputActivity to allow entering a new memo.
 */
class AddMemoActionCallback : ActionCallback {
    private val TAG = "AddMemoActionCallback"

    companion object {
        const val VAULT_DIR_KEY = "vault_dir"
        const val NOTE_FILE_KEY = "note_file"
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val vaultDir = parameters[ActionParameters.Key<String>(VAULT_DIR_KEY)]
        val noteFile = parameters[ActionParameters.Key<String>(NOTE_FILE_KEY)]

        if (vaultDir.isNullOrEmpty() || noteFile.isNullOrEmpty()) {
            Log.w(TAG, "Missing parameters: vaultDir=$vaultDir, noteFile=$noteFile")
            return
        }

        Log.d(TAG, "Launching MemoInputActivity for: $vaultDir / $noteFile")

        val intent = Intent(context, MemoInputActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(MemoInputActivity.EXTRA_VAULT_DIR, vaultDir)
            putExtra(MemoInputActivity.EXTRA_NOTE_FILE, noteFile)
        }

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MemoInputActivity", e)
        }
    }
}
