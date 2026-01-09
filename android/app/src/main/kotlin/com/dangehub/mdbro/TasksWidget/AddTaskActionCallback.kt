package com.dangehub.mdbro

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback

class AddTaskActionCallback : ActionCallback {
    private val TAG = "AddTaskActionCallback"

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        Log.d(TAG, "AddTaskActionCallback triggered - launching MainActivity to add new task")
        
        // Launch MainActivity with an intent extra to indicate we want to add a new task
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("action", "add_task")
        }
        
        context.startActivity(intent)
    }
}
