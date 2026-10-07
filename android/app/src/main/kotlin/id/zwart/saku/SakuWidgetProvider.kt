package id.zwart.saku

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Widget "Saku hari ini": total pengeluaran hari ini + tombol buka aplikasi.
 */
class SakuWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val total = context.getSharedPreferences("saku_native", Context.MODE_PRIVATE)
            .getInt("widget_total_today", -1)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, total))
        }
    }

    companion object {
        fun buildViews(context: Context, total: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.saku_widget)
            views.setTextViewText(
                R.id.widget_total,
                if (total < 0) "Buka Saku" else "Rp${format(total)}"
            )
            val openApp = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.widget_root, openApp)
            return views
        }

        fun updateAll(context: Context) {
            val total = context.getSharedPreferences("saku_native", Context.MODE_PRIVATE)
                .getInt("widget_total_today", -1)
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SakuWidgetProvider::class.java))
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context, total))
            }
        }

        private fun format(n: Int): String {
            val s = n.toString()
            val sb = StringBuilder()
            for (i in s.indices) {
                sb.append(s[i])
                val remain = s.length - 1 - i
                if (remain > 0 && remain % 3 == 0) sb.append('.')
            }
            return sb.toString()
        }
    }
}
