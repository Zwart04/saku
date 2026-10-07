package id.zwart.saku.notifications

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import id.zwart.saku.ai.MoneyAgent
import id.zwart.saku.data.Expense
import id.zwart.saku.data.ExpenseRepository
import id.zwart.saku.data.PendingExpense
import id.zwart.saku.storage.FolderStore
import id.zwart.saku.storage.Prefs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Pembaca notifikasi (NotificationListenerService).
 * Notifikasi keuangan yang mengandung nominal otomatis jadi draft pengeluaran:
 * langsung tercatat kalau user mengaktifkan auto-add, kalau tidak masuk daftar
 * "Menunggu konfirmasi" di dalam aplikasi.
 */
class ExpenseNotificationListener : NotificationListenerService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = listOfNotNull(
            extras.getCharSequence(Notification.EXTRA_TEXT),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT),
            extras.getCharSequence(Notification.EXTRA_SUB_TEXT)
        ).joinToString(" ")

        if (title.isBlank() && text.isBlank()) return

        val combined = "$title $text".lowercase()
        val isFinancial = FINANCIAL_KEYWORDS.any { combined.contains(it) }
        if (!isFinancial) return

        val parsed = MoneyAgent.parseNotification(title, text) ?: return
        val amount = parsed.first
        val merchant = parsed.second
        if (amount <= 0) return

        val category = MoneyAgent.guessNotifCategory("$merchant $title $text")

        scope.launch {
            val store = FolderStore(applicationContext)
            val prefs = Prefs(applicationContext)
            val repo = ExpenseRepository(store)
            if (prefs.autoAddNotifications) {
                repo.add(
                    Expense(
                        timestamp = System.currentTimeMillis(),
                        amount = amount,
                        merchant = merchant,
                        category = category,
                        note = "$title: $text".take(160),
                        source = "notification"
                    )
                )
            } else {
                repo.addPending(
                    PendingExpense(
                        timestamp = System.currentTimeMillis(),
                        amount = amount,
                        merchant = merchant,
                        category = category,
                        rawText = "$title: $text".take(160),
                        source = "notification"
                    )
                )
            }
        }
    }

    companion object {
        private val FINANCIAL_KEYWORDS = listOf(
            "transfer", "pembayaran", "dibayar", "berhasil", "bca", "bri",
            "mandiri", "bni", "jenius", "jago", "gopay", "ovo", "dana",
            "shopeepay", "linkaja", "saldo", "debit", "payment", "purchase",
            "transaksi", "deposit", "topup", "top up"
        )
    }
}
