package com.example.lock_screen_love

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class HomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_layout)
            
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val timeText = prefs.getString("widget_time", "10:00")
            val messageText = prefs.getString("widget_message", "Tu esi nuostabus!")
            
            views.setTextViewText(R.id.widget_time, timeText)
            views.setTextViewText(R.id.widget_message, messageText)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}