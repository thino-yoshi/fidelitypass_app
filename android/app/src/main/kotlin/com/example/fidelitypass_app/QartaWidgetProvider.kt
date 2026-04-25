package com.example.fidelitypass_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class QartaWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            val merchantName = prefs.getString("widget_merchant_name", "Mon commerce") ?: "Mon commerce"
            val stampsCount = prefs.getInt("widget_stamps_count", 0)
            val stampsRequired = prefs.getInt("widget_stamps_required", 10)
            val rewardDescription = prefs.getString("widget_reward_description", "Recompense") ?: "Recompense"

            val views = RemoteViews(context.packageName, R.layout.qarta_widget)

            views.setTextViewText(R.id.widget_merchant_name, merchantName)
            views.setTextViewText(R.id.widget_stamps_text, "$stampsCount/$stampsRequired tampons")
            views.setTextViewText(R.id.widget_reward_text, rewardDescription)

            // Tap to open app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_merchant_name, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
