package com.scanworks.obsi

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback

class OpenTaskActionCallback : ActionCallback {
    private val TAG = "OpenTaskActionCallback"
    
    companion object {
        const val TASK_JSON_KEY = "taskJson"
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val taskJson = parameters[ActionParameters.Key<String>(TASK_JSON_KEY)] ?: return
        
        Log.d(TAG, "OpenTaskActionCallback triggered - launching MainActivity with task: $taskJson")
        
        // Launch MainActivity with the specific task data
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("action", "open_task")
            putExtra("task_json", taskJson)
        }
        
        context.startActivity(intent)
    }
}
