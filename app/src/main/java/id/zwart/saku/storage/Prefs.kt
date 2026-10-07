package id.zwart.saku.storage

import android.content.Context

/**
 * Preferensi ringan ( SharedPreferences ) — dipisah dari data pengeluaran karena
 * data pengeluaran sengaja disimpan di folder SAF yang survive uninstall.
 */
class Prefs(private val context: Context) {

    private val sp =
        context.getSharedPreferences("zwart_saku_prefs", Context.MODE_PRIVATE)

    var autoAddNotifications: Boolean
        get() = sp.getBoolean(KEY_AUTO_ADD, false)
        set(value) {
            sp.edit().putBoolean(KEY_AUTO_ADD, value).apply()
        }

    var firstLaunchTip: Boolean
        get() = sp.getBoolean(KEY_TIP_SHOWN, false)
        set(value) {
            sp.edit().putBoolean(KEY_TIP_SHOWN, value).apply()
        }

    companion object {
        private const val KEY_AUTO_ADD = "auto_add_notifications"
        private const val KEY_TIP_SHOWN = "tip_shown"
    }
}
