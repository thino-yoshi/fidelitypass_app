package com.example.fidelitypass_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.RemoteViews
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

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
            val widgetData = HomeWidgetPlugin.getData(context)

            val merchantName = widgetData.getString("widget_merchant_name", "Mon commerce")
            val stampsCount = widgetData.getInt("widget_stamps_count", 0)
            val stampsRequired = widgetData.getInt("widget_stamps_required", 10)
            val rewardDescription = widgetData.getString("widget_reward_description", "Récompense")

            val views = RemoteViews(context.packageName, R.layout.qarta_widget)

            views.setTextViewText(R.id.widget_merchant_name, merchantName)
            views.setTextViewText(R.id.widget_stamps_text, "$stampsCount/$stampsRequired tampons")
            views.setTextViewText(R.id.widget_reward_text, "🎁 $rewardDescription")

            val progress = if (stampsRequired > 0) (stampsCount * 100) / stampsRequired else 0
            views.setProgressBar(R.id.widget_progress, 100, progress, false)

            // Tap to open app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_stamps_text, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
