package id.zwart.saku.ai

import id.zwart.saku.data.ChartKind
import id.zwart.saku.data.DashboardCard
import id.zwart.saku.data.Expense
import id.zwart.saku.data.ExpenseRepository
import id.zwart.saku.data.defaultDashboard
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/** Hasil agent: pengeluaran tercatat, dashboard berubah, atau sekadar info. */
sealed class AgentResult {
    data class Recorded(val expense: Expense, val message: String) : AgentResult()
    data class DashboardUpdated(val cards: List<DashboardCard>, val message: String) : AgentResult()
    data class Info(val message: String) : AgentResult()
}

/**
 * Agent lokal 100% offline. Tidak ada model eksternal — semua perintah dipahami
 * lewat parser NLU berbasis aturan (bahasa Indonesia + singkatan uang).
 */
object MoneyAgent {

    val CATEGORIES = listOf(
        "Makanan", "Transportasi", "Belanja", "Tagihan", "Hiburan",
        "Kesehatan", "Pendidikan", "Lainnya"
    )

    private val categoryKeywords = mapOf(
        "Makanan" to listOf(
            "makan", "sarapan", "lunch", "dinner", "bakso", "mie", "nasi", "kopi",
            "ngopi", "snack", "sate", "ayam", "geprek", "seblak", "warung", "resto",
            "cafe", "warkop", "martabak", "roti", "goreng", "jajan"
        ),
        "Transportasi" to listOf(
            "gojek", "grab", "ojek", "ojol", "bensin", "pertalite", "pertamax",
            "parkir", "tol", "transport", "kereta", "krl", "bus", "taksi", "maxim"
        ),
        "Belanja" to listOf(
            "belanja", "tokopedia", "shopee", "bukalapak", "lazada", "toko", "minimarket",
            "indomaret", "alfamart", "supermarket", "baju", "sepatu"
        ),
        "Tagihan" to listOf(
            "pulsa", "listrik", "pdam", "wifi", "internet", "token", "tagihan",
            "pln", "netflix", "spotify", "iuran", "langganan"
        ),
        "Hiburan" to listOf(
            "game", "film", "nonton", "bioskop", "tiket", "wisata", "liburan",
            "konser", "playstation", "xbox", "steam"
        ),
        "Kesehatan" to listOf(
            "obat", "dokter", "klinik", "apotik", "apotek", "periksa", "vitamin", "rumah sakit"
        ),
        "Pendidikan" to listOf(
            "kuliah", "buku", "kursus", "les", "sekolah", "spp", "skripsi", "uang sekolah"
        )
    )

    private val monthNames = mapOf(
        "januari" to 1, "jan" to 1,
        "februari" to 2, "feb" to 2,
        "maret" to 3, "mar" to 3,
        "april" to 4, "apr" to 4,
        "mei" to 5,
        "juni" to 6, "jun" to 6,
        "juli" to 7, "jul" to 7,
        "agustus" to 8, "agu" to 8, "ags" to 8,
        "september" to 9, "sep" to 9,
        "oktober" to 10, "okt" to 10,
        "november" to 11, "nov" to 11,
        "desember" to 12, "des" to 12
    )

    private val chartKindWords = mapOf(
        "bar" to ChartKind.BAR,
        "batang" to ChartKind.BAR,
        "garis" to ChartKind.LINE,
        "line" to ChartKind.LINE,
        "tren" to ChartKind.LINE,
        "trend" to ChartKind.LINE,
        "pie" to ChartKind.PIE,
        "bulat" to ChartKind.PIE,
        "lingkaran" to ChartKind.PIE
    )

    private val dashWord = Regex("""(?i)(grafik|chart|kartu|dashboard|tampil|menampilkan|lihat|rekap|ringkasan|berapa|total|reset)""")
    private val reAddCard = Regex("""(?i)(tambah|buat|bikin)\s+(?:satu\s+)?kartu\s+(.*)""")
    private val reDelCard = Regex("""(?i)(hapus|buang)\s+(?:satu\s+)?kartu\s+(.*)""")
    private val reChangeChart = Regex("""(?i)(?:ubah|ganti|jadikan|set)\b.*?\b(?:grafik|chart)\b.*""")
    private val reShowRange = Regex("""(?i)(?:tampilkan|lihat|pamerkan)\s+(?:pengeluaran|belanja|spend)\s+(.*)""")
    private val reSummary = Regex("""(?i)\b(?:berapa|total|ringkasan|rekap|laporan)\b""")
    private val reResetDash = Regex("""(?i)reset\s+dashboard""")
    private val reNdays = Regex("""(?i)(\d+)\s*s?hari\s*(terakhir|lalu|belakang)""")

    private val amountRegexes = listOf(
        Regex("""(?i)(\d+)(?:[.,]\d+)?\s*(ribu|rb|k|jt|juta)\b"""),
        Regex("""(?i)(?:rp\.?|idr)\s*(\d[\d.,]*)(?:\s*(?:ribu|rb|k|jt|juta))?"""),
        Regex("""\b(\d[\d.,]{3,})(?!\d)\b""")
    )

    fun run(commandRaw: String, expenses: List<Expense>, cards: List<DashboardCard>): AgentResult {
        val command = normalize(commandRaw)
        if (command.isBlank()) {
            return AgentResult.Info(helpText())
        }

        if (reResetDash.containsMatchIn(command)) {
            return AgentResult.DashboardUpdated(defaultDashboard(), "Dashboard dikembalikan ke tampilan awal.")
        }

        if (dashWord.containsMatchIn(command)) {
            reAddCard.find(command)?.let {
                return buildAddCard(it.groupValues[2].trim(), cards)
            }
            reDelCard.find(command)?.let {
                return buildDeleteCard(it.groupValues[2].trim(), cards)
            }
            if (reChangeChart.containsMatchIn(command)) {
                return buildChangeChart(command, cards)
            }
            reShowRange.find(command)?.let {
                return buildShowRange(it.groupValues[1].trim(), cards)
            }
            if (reSummary.containsMatchIn(command)) {
                return buildSummary(command, expenses)
            }
        }

        val amount = parseAmount(command)
        if (amount != null && amount > 0) {
            val (category, merchant) = guessCategoryAndMerchant(command)
            val expense = Expense(
                amount = amount,
                category = category,
                merchant = merchant,
                note = commandRaw,
                source = "agent"
            )
            val merchantPart = merchant.takeIf { it.isNotBlank() }?.let { " • $it" }.orEmpty()
            return AgentResult.Recorded(expense, "Dicatat: ${formatRupiah(amount)} — $category$merchantPart")
        }

        return AgentResult.Info(helpText())
    }

    private fun helpText(): String = "Hmm, belum paham. Coba misalnya:\n" +
        "• makan bakso 25 ribu\n" +
        "• grab 30k\n" +
        "• ubah grafik jadi pie\n" +
        "• tampilkan pengeluaran 1-7 Oktober\n" +
        "• tambah kartu bar 7 hari\n" +
        "• total bulan ini"

    fun chartKindOf(text: String): ChartKind? =
        chartKindWords.entries.firstOrNull { Regex("""\b${Regex.escape(it.key)}\b""").containsMatchIn(text) }?.value

    fun chartLabel(kind: ChartKind): String = when (kind) {
        ChartKind.BAR -> "bar"
        ChartKind.LINE -> "line (garis)"
        ChartKind.PIE -> "pie (bulat)"
    }

    fun parseAmount(textRaw: String): Long? {
        val text = normalize(textRaw)
        for (rx in amountRegexes) {
            val m = rx.find(text) ?: continue
            val digits = m.groupValues[1].replace(".", "").replace(",", "").toLongOrNull() ?: continue
            val suffix = m.groupValues.getOrNull(2).orEmpty().trim()
            val multiplier = when (suffix) {
                "ribu", "rb", "k" -> 1000L
                "jt", "juta" -> 1_000_000L
                "" -> if (digits < 100) 1000L else 1L
                else -> 1L
            }
            return digits * multiplier
        }
        return null
    }

    fun guessCategoryAndMerchant(textRaw: String): Pair<String, String> {
        val text = normalize(textRaw)
        var category = "Lainnya"
        var bestScore = 0
        for ((cat, keys) in categoryKeywords) {
            val score = keys.count { text.contains(it) }
            if (score > bestScore) {
                bestScore = score
                category = cat
            }
        }

        var merchant = text
            .replace(Regex("""(?i)(?:rp\.?|idr)\s*\d[\d.,]*"""), " ")
            .replace(Regex("""\d[\d.,]{3,}"""), " ")
            .replace(Regex("""(?i)\d+\s*(?:ribu|rb|k|jt|juta)\b"""), " ")
            .replace(Regex("""[^a-z\s-]"""), " ")
        merchant = merchant.split(Regex("""\s+"""))
            .filter { it.isNotBlank() }
            .filterNot { STOP_WORDS.contains(it) }
            .joinToString(" ") { w -> w.replaceFirstChar { it.uppercase() } }
        if (merchant.length > 40) merchant = merchant.take(40).trim()
        if (merchant.isBlank()) merchant = category
        return category to merchant
    }

    private val STOP_WORDS = setOf(
        "catat", "catatkan", "belanja", "beli", "bayar", "tadi", "habis", "sudah",
        "saya", "aku", "gue", "gua", "gw", "makan", "pengeluaran",
        "buat", "pake", "pakai", "uang", "jajan"
    )

    fun parseDateRange(textRaw: String): Triple<LocalDate, LocalDate, String>? = parseDateRanges(textRaw)

    private fun parseDateRanges(textRaw: String): Triple<LocalDate, LocalDate, String>? {
        val text = normalize(textRaw)
        val today = LocalDate.now()

        reNdays.find(text)?.let { m ->
            val n = m.groupValues[1].toIntOrNull() ?: 30
            val from = today.minusDays((n - 1).toLong())
            return Triple(from, today, "$n hari terakhir")
        }
        if (Regex("""\b(?:hari\s+ini)\b""").containsMatchIn(text)) return Triple(today, today, "Hari ini")
        if (Regex("""\b(?:kemarin|kemaren)\b""").containsMatchIn(text)) {
            val y = today.minusDays(1)
            return Triple(y, y, "Kemarin")
        }
        if (Regex("""\b(?:minggu\s*ini)\b""").containsMatchIn(text)) {
            val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
            return Triple(monday, today, "Minggu ini")
        }
        if (Regex("""\b(?:bulan\s+lalu|bulan\s+kemarin)\b""").containsMatchIn(text)) {
            val first = today.minusMonths(1).withDayOfMonth(1)
            return Triple(first, first.withDayOfMonth(first.lengthOfMonth()), first.monthName() + " lalu")
        }
        if (Regex("""\b(?:bulan\s*ini)\b""").containsMatchIn(text)) {
            return Triple(today.withDayOfMonth(1), today, "${today.monthName()} ini")
        }
        if (Regex("""\b(?:tahun\s*ini)\b""").containsMatchIn(text)) {
            return Triple(today.withDayOfYear(1), today, "Tahun ini")
        }

        val range = Regex(
            """(\d{1,2})(?:\s*(?:s/|sd|smp|sampe|sampai|-|ke)\s*(\d{1,2}))?\s*(jan(?:uari)?|feb(?:ruari)?|maret|mar|april|apr|mei|juni|jun|juli|jul|agustus|agu|ags|september|sep|oktober|okt|november|nov|desember|des)(?:\s+(\d{4}))?"""
        ).find(text)
        if (range != null) {
            val dayFrom = range.groupValues[1].toIntOrNull() ?: return null
            val dayTo = range.groupValues[2].toIntOrNull() ?: dayFrom
            val month = monthOf(range.groupValues[3]) ?: return null
            val year = range.groupValues[4].toIntOrNull() ?: today.year
            val from = try { LocalDate.of(year, month, dayFrom) } catch (t: Throwable) { return null }
            val to = try { LocalDate.of(year, month, dayTo) } catch (t: Throwable) { return null }
            return if (to.isBefore(from)) {
                val from2 = to.minusDays(6)
                Triple(from2, to, "${pretty(from2)} – ${pretty(to)}")
            } else {
                Triple(from, to, if (from == to) pretty(from) else "${pretty(from)} – ${pretty(to)}")
            }
        }

        val isoDates = Regex("""\d{4}-\d{2}-\d{2}""").findAll(text).toList()
        if (isoDates.size >= 2) {
            val f = runCatching { LocalDate.parse(isoDates[0].value) }.getOrNull() ?: return null
            val t = runCatching { LocalDate.parse(isoDates[1].value) }.getOrNull() ?: return null
            return Triple(f, t, if (f == t) pretty(f) else "${pretty(f)} – ${pretty(t)}")
        }
        if (isoDates.size == 1) {
            val d = runCatching { LocalDate.parse(isoDates[0].value) }.getOrNull() ?: return null
            return Triple(d, d, pretty(d))
        }
        return null
    }

    private fun monthOf(name: String): Int? = monthNames[name.trim()]

    private fun LocalDate.monthName(): String =
        month.getDisplayName(TextStyle.FULL, Locale("id"))

    private fun pretty(d: LocalDate): String =
        "${d.dayOfMonth} ${d.monthName()}"

    fun formatRupiah(amount: Long): String {
        val nf = java.text.NumberFormat.getNumberInstance(Locale("id"))
        return "Rp" + nf.format(amount)
    }

    private fun buildChangeChart(command: String, cards: List<DashboardCard>): AgentResult {
        val kind = chartKindOf(command)
            ?: return AgentResult.Info("Ke tipe apa? bar, line/garis (line), atau pie/bulat (pie)?")
        val updated = cards.map { if (it.type == "chart") it.copy(chartKind = kind) else it }
        return AgentResult.DashboardUpdated(updated, "Semua kartu grafik diubah ke ${chartLabel(kind)}.")
    }

    private fun buildShowRange(rest: String, cards: List<DashboardCard>): AgentResult {
        val kind = chartKindOf(rest)
        val range = parseDateRanges(rest)
        return if (range != null) {
            val (from, to, label) = range
            val newCard = DashboardCard(
                type = "chart",
                title = "Pengeluaran $label",
                chartKind = kind ?: ChartKind.BAR,
                days = 30,
                startDate = from.toString(),
                endDate = to.toString()
            )
            val remaining = cards.filterNot { c ->
                c.startDate != null && c.endDate != null &&
                    c.startDate == from.toString() && c.endDate == to.toString()
            }
            AgentResult.DashboardUpdated(remaining + newCard, "Kartu grafik $label ditambahkan.")
        } else {
            val days = Regex("""\b(\d+)\b""").find(rest)?.groupValues?.get(1)?.toIntOrNull() ?: 30
            val newCard = DashboardCard(
                type = "chart",
                title = "Trend terakhir $days hari",
                chartKind = kind ?: ChartKind.BAR,
                days = days
            )
            AgentResult.DashboardUpdated(cards + newCard, "Kartu trend $days hari ditambahkan.")
        }
    }

    private fun buildAddCard(rest: String, cards: List<DashboardCard>): AgentResult {
        val kind = chartKindOf(rest)
        val range = parseDateRanges(rest)
        val days = Regex("""\b(\d+)\b""").find(rest)?.groupValues?.get(1)?.toIntOrNull() ?: 30
        val card = when {
            kind != null -> DashboardCard(
                type = "chart",
                title = "Grafik " + (range?.third ?: "terakhir $days hari"),
                chartKind = kind,
                days = days,
                startDate = range?.first?.toString(),
                endDate = range?.second?.toString()
            )
            Regex("""\b(?:kategori|top)\b""").containsMatchIn(rest) -> DashboardCard(
                type = "category",
                title = "Kategori " + (range?.third ?: "terakhir $days hari"),
                days = days,
                startDate = range?.first?.toString(),
                endDate = range?.second?.toString()
            )
            Regex("""\b(?:transaksi|riwayat|list)\b""").containsMatchIn(rest) -> DashboardCard(
                type = "list",
                title = "Transaksi " + (range?.third ?: "terakhir $days hari"),
                days = days,
                startDate = range?.first?.toString(),
                endDate = range?.second?.toString()
            )
            range != null -> DashboardCard(
                type = "total",
                title = "Total " + range.third,
                days = days,
                startDate = range.first.toString(),
                endDate = range.second.toString()
            )
            else -> DashboardCard(type = "total", title = "Total terakhir $days hari", days = days)
        }
        return AgentResult.DashboardUpdated(cards + card, "Kartu baru: ${card.title}")
    }

    private fun buildDeleteCard(rest: String, cards: List<DashboardCard>): AgentResult {
        val lower = normalize(rest)
        val keyword = if (lower.isNotBlank()) lower.split(" ").first().trim() else ""
        if (keyword.isBlank()) {
            return AgentResult.Info("Kartu mana yang mau dihapus? Misal: hapus kartu pie.")
        }
        val targets = cards.filter {
            normalize(it.title).contains(keyword) ||
                it.chartKind.name.lowercase() == keyword ||
                it.type == keyword
        }
        if (targets.isEmpty()) {
            return AgentResult.Info("Tidak ada kartu yang cocok dengan \"$rest\".")
        }
        val remaining = cards.filterNot { it in targets }
        if (remaining.isEmpty()) {
            return AgentResult.Info("Dashboard tidak bisa kosong — sisakan minimal 1 kartu.")
        }
        return AgentResult.DashboardUpdated(remaining, "Kartu \"$keyword\" dihapus.")
    }

    private fun buildSummary(command: String, expenses: List<Expense>): AgentResult {
        val range = parseDateRanges(command) ?: Triple(
            LocalDate.now().withDayOfMonth(1),
            LocalDate.now(),
            LocalDate.now().monthName() + " ini"
        )
        val (from, to, label) = range
        val list = expenses.filter { ExpenseRepository.inRange(it, from, to) }
        if (list.isEmpty()) return AgentResult.Info("Belum ada pengeluaran di periode $label.")
        val total = list.sumOf { it.amount }
        val topCategory = list.groupBy { it.category }
            .mapValues { it.value.sumOf { e -> e.amount } }
            .toList()
            .sortedByDescending { it.second }
            .take(3)
            .joinToString("\n") { (cat, sum) -> "• $cat: ${formatRupiah(sum)}" }
        return AgentResult.Info(
            "Total $label: ${formatRupiah(total)} dari ${list.size} transaksi.\nKategori terbesar:\n$topCategory"
        )
    }

    /** Parser pesan notifikasi bank/dompet digital → (amount, merchant). */
    fun parseNotification(title: String, text: String): Pair<Long, String>? {
        val amount = parseAmount("$title $text") ?: return null
        if (amount <= 0) return null
        val merchantRaw = title
            .replace(Regex("""(?i)(?:rp\.?|idr)\s*\d[\d.,]*"""), " ")
            .replace(Regex("""\d[\d.,]{3,}"""), " ")
            .replace(Regex("""[^A-Za-z\s-]"""), " ")
            .trim()
        val merchant = merchantRaw
            .split(Regex("""\s+"""))
            .filter { it.isNotBlank() }
            .joinToString(" ") { w -> w.lowercase().replaceFirstChar { it.uppercase() } }
        return amount to merchant
    }

    fun guessNotifCategory(fullText: String): String = guessCategoryAndMerchant(fullText).first
}
