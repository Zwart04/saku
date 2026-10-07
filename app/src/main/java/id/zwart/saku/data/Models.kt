package id.zwart.saku.data

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

enum class ChartKind { BAR, LINE, PIE }

data class Expense(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Long = System.currentTimeMillis(),
    val amount: Long,
    val category: String = "Lainnya",
    val merchant: String = "",
    val note: String = "",
    val source: String = "manual"
)

data class PendingExpense(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Long = System.currentTimeMillis(),
    val amount: Long,
    val merchant: String = "",
    val category: String = "Lainnya",
    val rawText: String = "",
    val source: String = "notification"
)

data class DashboardCard(
    val id: String = UUID.randomUUID().toString(),
    val type: String = "total",
    val title: String = "Total pengeluaran",
    val chartKind: ChartKind = ChartKind.BAR,
    val days: Int = 30,
    val startDate: String? = null,
    val endDate: String? = null,
    val limit: Int = 5,
    val enabled: Boolean = true
) {
    fun rangeLabel(): String = if (startDate != null && endDate != null) "$startDate s/d $endDate"
    else "Terakhir $days hari"

    companion object {
        fun fromJson(o: JSONObject): DashboardCard = DashboardCard(
            id = o.optString("id", UUID.randomUUID().toString()),
            type = o.optString("type", "total"),
            title = o.optString("title", "Kartu"),
            chartKind = runCatching { ChartKind.valueOf(o.optString("chartKind", "BAR")) }.getOrDefault(ChartKind.BAR),
            days = o.optInt("days", 30),
            startDate = if (o.isNull("startDate")) null else o.optString("startDate"),
            endDate = if (o.isNull("endDate")) null else o.optString("endDate"),
            limit = o.optInt("limit", 5),
            enabled = o.optBoolean("enabled", true)
        )
    }

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("type", type)
        put("title", title)
        put("chartKind", chartKind.name)
        put("days", days)
        put("startDate", startDate ?: JSONObject.NULL)
        put("endDate", endDate ?: JSONObject.NULL)
        put("limit", limit)
        put("enabled", enabled)
    }
}

fun defaultDashboard(): List<DashboardCard> = listOf(
    DashboardCard(type = "total", title = "Pengeluaran bulan ini", days = 30),
    DashboardCard(type = "chart", title = "Trend harian — bulan ini", chartKind = ChartKind.BAR, days = 30),
    DashboardCard(type = "category", title = "Kategori terbesar — bulan ini", days = 30, limit = 5),
    DashboardCard(type = "list", title = "Transaksi terbaru", days = 30, limit = 8)
)

object Json {
    fun expenseToJson(e: Expense): JSONObject = JSONObject().apply {
        put("id", e.id)
        put("timestamp", e.timestamp)
        put("amount", e.amount)
        put("category", e.category)
        put("merchant", e.merchant)
        put("note", e.note)
        put("source", e.source)
    }

    fun expenseFromJson(o: JSONObject): Expense = Expense(
        id = o.optString("id", UUID.randomUUID().toString()),
        timestamp = o.optLong("timestamp", System.currentTimeMillis()),
        amount = o.optLong("amount", 0L),
        category = o.optString("category", "Lainnya"),
        merchant = o.optString("merchant", ""),
        note = o.optString("note", ""),
        source = o.optString("source", "manual")
    )

    fun pendingToJson(p: PendingExpense): JSONObject = JSONObject().apply {
        put("id", p.id)
        put("timestamp", p.timestamp)
        put("amount", p.amount)
        put("merchant", p.merchant)
        put("category", p.category)
        put("rawText", p.rawText)
        put("source", p.source)
    }

    fun pendingFromJson(o: JSONObject): PendingExpense = PendingExpense(
        id = o.optString("id", UUID.randomUUID().toString()),
        timestamp = o.optLong("timestamp", System.currentTimeMillis()),
        amount = o.optLong("amount", 0L),
        merchant = o.optString("merchant", ""),
        category = o.optString("category", "Lainnya"),
        rawText = o.optString("rawText", ""),
        source = o.optString("source", "notification")
    )

    fun expensesToJson(list: List<Expense>): String {
        val arr = JSONArray()
        list.forEach { arr.put(expenseToJson(it)) }
        return arr.toString(2)
    }

    fun expensesFromJson(raw: String): List<Expense> = try {
        val arr = JSONArray(raw)
        (0 until arr.length()).map { expenseFromJson(arr.getJSONObject(it)) }
    } catch (t: Throwable) {
        emptyList()
    }

    fun pendingToJsonString(list: List<PendingExpense>): String {
        val arr = JSONArray()
        list.forEach { arr.put(pendingToJson(it)) }
        return arr.toString(2)
    }

    fun pendingFromJson(raw: String): List<PendingExpense> = try {
        val arr = JSONArray(raw)
        (0 until arr.length()).map { pendingFromJson(arr.getJSONObject(it)) }
    } catch (t: Throwable) {
        emptyList()
    }

    fun cardsToJson(list: List<DashboardCard>): String {
        val arr = JSONArray()
        list.forEach { arr.put(it.toJson()) }
        return arr.toString(2)
    }

    fun cardsFromJson(raw: String): List<DashboardCard> = try {
        val arr = JSONArray(raw)
        (0 until arr.length()).map { DashboardCard.fromJson(arr.getJSONObject(it)) }
    } catch (t: Throwable) {
        emptyList()
    }
}
