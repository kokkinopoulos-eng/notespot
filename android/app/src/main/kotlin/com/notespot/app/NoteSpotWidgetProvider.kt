package com.notespot.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NoteSpotWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.notespot_widget).apply {
                setOnClickPendingIntent(
                    R.id.btn_text,
                    makeLaunchIntent(context, "notespot://create?action=text", 1001),
                )
                setOnClickPendingIntent(
                    R.id.btn_camera,
                    makeLaunchIntent(context, "notespot://create?action=camera", 1002),
                )
                setOnClickPendingIntent(
                    R.id.btn_voice,
                    makeLaunchIntent(context, "notespot://create?action=voice", 1003),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun makeLaunchIntent(context: Context, uriString: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.parse(uriString)
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }
}
