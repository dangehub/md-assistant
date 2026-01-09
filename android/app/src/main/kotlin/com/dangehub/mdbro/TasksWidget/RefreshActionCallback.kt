package com.dangehub.mdbro

import android.content.Context
import android.util.Log
import androidx.core.net.toUri
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class RefreshActionCallback : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
       Log.d("ObsiWidget", "Refresh button clicked")
        // Call the requestTasks method to trigger background intent
        ObsiWidget().apply {
            // val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context,
            //     "obsiWidget://request_tasks".toUri())
            // backgroundIntent.send()
        }
    }
}
