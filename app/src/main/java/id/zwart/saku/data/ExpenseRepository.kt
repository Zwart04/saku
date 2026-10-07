package id.zwart.saku.data

import id.zwart.saku.storage.FolderStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class ExpenseRepository(private val store: FolderStore) {

    suspend fun initFolder(): Boolean = withContext(Dispatchers.IO) {
        if (!store.isReady()) return@withContext false
        if (store.read(FolderStore.DASHBOARD_FILE) == null) {
            store.write(FolderStore.DASHBOARD_FILE, Json.cardsToJson(defaultDashboard()))
        }
        if (store.read(FolderStore.EXPENSES_FILE) == null) {
            store.write(FolderStore.EXPENSES_FILE, Json.expensesToJson(emptyList()))
        }
        if (store.read(FolderStore.PENDING_FILE) == null) {
            store.write(FolderStore.PENDING_FILE, Json.pendingToJsonString(emptyList()))
        }
        true
    }

    suspend fun expenses(): List<Expense> = withContext(Dispatchers.IO) {
        Json.expensesFromJson(store.read(FolderStore.EXPENSES_FILE).orEmpty())
            .sortedByDescending { it.timestamp }
    }

    suspend fun pending(): List<PendingExpense> = withContext(Dispatchers.IO) {
        Json.pendingFromJson(store.read(FolderStore.PENDING_FILE).orEmpty())
            .sortedByDescending { it.timestamp }
    }

    suspend fun dashboard(): List<DashboardCard> = withContext(Dispatchers.IO) {
        val raw = store.read(FolderStore.DASHBOARD_FILE)
        val loaded = raw?.let { Json.cardsFromJson(it) }.orEmpty()
        if (loaded.isEmpty()) defaultDashboard() else loaded
    }

    suspend fun add(expense: Expense): Boolean = withContext(Dispatchers.IO) {
        val list = Json.expensesFromJson(store.read(FolderStore.EXPENSES_FILE).orEmpty())
            .toMutableList()
        list.add(expense)
        list.sortByDescending { it.timestamp }
        store.write(FolderStore.EXPENSES_FILE, Json.expensesToJson(list))
    }

    suspend fun deleteExpense(id: String): Boolean = withContext(Dispatchers.IO) {
        val list = Json.expensesFromJson(store.read(FolderStore.EXPENSES_FILE).orEmpty())
            .filterNot { it.id == id }
        store.write(FolderStore.EXPENSES_FILE, Json.expensesToJson(list))
    }

    suspend fun addPending(p: PendingExpense): Unit = withContext(Dispatchers.IO) {
        val list = Json.pendingFromJson(store.read(FolderStore.PENDING_FILE).orEmpty())
            .toMutableList()
        if (list.none { it.rawText == p.rawText && it.amount == p.amount }) {
            list.add(0, p)
            store.write(FolderStore.PENDING_FILE, Json.pendingToJsonString(list))
        }
    }

    suspend fun acceptPending(id: String): Unit = withContext(Dispatchers.IO) {
        val pend = Json.pendingFromJson(store.read(FolderStore.PENDING_FILE).orEmpty())
        val p = pend.firstOrNull { it.id == id } ?: return@withContext
        add(
            Expense(
                timestamp = p.timestamp,
                amount = p.amount,
                merchant = p.merchant,
                category = p.category,
                note = p.rawText,
                source = p.source
            )
        )
        store.write(
            FolderStore.PENDING_FILE,
            Json.pendingToJsonString(pend.filterNot { it.id == id })
        )
    }

    suspend fun rejectPending(id: String): Unit = withContext(Dispatchers.IO) {
        val pend = Json.pendingFromJson(store.read(FolderStore.PENDING_FILE).orEmpty())
        store.write(FolderStore.PENDING_FILE, Json.pendingToJsonString(pend.filterNot { it.id == id }))
    }

    suspend fun saveDashboard(cards: List<DashboardCard>): Boolean = withContext(Dispatchers.IO) {
        store.write(FolderStore.DASHBOARD_FILE, Json.cardsToJson(cards))
    }

    suspend fun exportCsv(): Boolean = withContext(Dispatchers.IO) {
        val list = Json.expensesFromJson(store.read(FolderStore.EXPENSES_FILE).orEmpty())
            .sortedBy { it.timestamp }
        if (!store.exists(FolderStore.EXPORT_FILE)) {
            store.appendToCsv(
                FolderStore.EXPORT_FILE,
                "tanggal,jumlah,kategori,merchant,catatan,sumber"
            )
        }
        list.forEach { e ->
            store.appendToCsv(
                FolderStore.EXPORT_FILE,
                listOf(
                    dateOf(e.timestamp),
                    e.amount,
                    csv(e.category),
                    csv(e.merchant),
                    csv(e.note),
                    csv(e.source)
                ).joinToString(",")
            )
        }
        true
    }

    private fun csv(v: String): String = "\"" + v.replace("\"", "'") + "\""

    companion object {
        val ZONE: ZoneId = ZoneId.systemDefault()

        fun dateOf(timestamp: Long): String =
            Instant.ofEpochMilli(timestamp).atZone(ZONE).toLocalDate().toString()

        fun localDateOf(timestamp: Long): LocalDate =
            Instant.ofEpochMilli(timestamp).atZone(ZONE).toLocalDate()

        fun inRange(expense: Expense, from: LocalDate, to: LocalDate): Boolean {
            val d = localDateOf(expense.timestamp)
            return !d.isBefore(from) && !d.isAfter(to)
        }

        fun lastDays(expense: Expense, days: Int): Boolean {
            val from = LocalDate.now(ZONE).minusDays(days.toLong() - 1)
            return inRange(expense, from, LocalDate.now(ZONE))
        }

        fun expensesInRange(list: List<Expense>, card: DashboardCard): List<Expense> {
            val today = LocalDate.now(ZONE)
            return if (card.startDate != null && card.endDate != null) {
                val from = runCatching { LocalDate.parse(card.startDate) }.getOrDefault(today.minusDays(29))
                val to = runCatching { LocalDate.parse(card.endDate) }.getOrDefault(today)
                list.filter { inRange(it, from, to) }
            } else {
                list.filter { lastDays(it, card.days) }
            }
        }
    }
}
