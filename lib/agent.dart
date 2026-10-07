import 'models.dart';

sealed class AgentResult {
  const AgentResult();
}

class AgentRecorded extends AgentResult {
  final List<Expense> expenses;
  final String message;
  AgentRecorded(this.expenses, this.message);
}

class AgentDashboardUpdated extends AgentResult {
  final List<CardDef> cards;
  final String message;
  AgentDashboardUpdated(this.cards, this.message);
}

class AgentInfo extends AgentResult {
  final String message;
  AgentInfo(this.message);
}

class MoneyAgent {
  static const List<String> categories = <String>[
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Kesehatan',
    'Pendidikan',
    'Lainnya',
  ];

  static final Map<String, List<String>> categoryKeywords = <String, List<String>>{
    'Makanan': [
      'makan', 'sarapan', 'lunch', 'dinner', 'bakso', 'mie', 'nasi', 'kopi', 'ngopi',
      'snack', 'sate', 'seblak', 'geprek', 'warung', 'resto', 'cafe', 'warkop', 'martabak',
      'roti', 'goreng', 'jajan', 'ayam', 'kentang', 'burger', 'pizza', 'starbucks',
      'es krim', 'es teh', 'teh', 'susu', 'nescafe', 'kopi gold', 'matcha',
    ],
    'Transportasi': [
      'gojek', 'grab', 'ojek', 'ojol', 'bensin', 'pertalite', 'pertamax', 'parkir',
      'tol', 'transport', 'kereta', 'krl', 'bus', 'taksi', 'maxim', 'setrum',
    ],
    'Belanja': [
      'belanja', 'tokopedia', 'shopee', 'bukalapak', 'lazada', 'toko', 'minimarket',
      'indomaret', 'alfamart', 'supermarket', 'baju', 'sepatu', 'renceng', 'pack',
    ],
    'Tagihan': [
      'pulsa', 'listrik', 'pdam', 'wifi', 'internet', 'token', 'tagihan', 'pln',
      'netflix', 'spotify', 'iuran', 'langganan', 'canva',
    ],
    'Hiburan': [
      'game', 'film', 'nonton', 'bioskop', 'tiket', 'wisata', 'liburan', 'konser',
      'playstation', 'xbox', 'steam',
    ],
    'Kesehatan': [
      'obat', 'dokter', 'klinik', 'apotik', 'apotek', 'periksa', 'vitamin', 'rumah sakit',
    ],
    'Pendidikan': [
      'kuliah', 'buku', 'kursus', 'les', 'sekolah', 'spp', 'skripsi', 'uang sekolah',
    ],
  };

  static final Map<String, int> monthNames = <String, int>{
    'januari': 1, 'jan': 1,
    'februari': 2, 'feb': 2,
    'maret': 3, 'mar': 3,
    'april': 4, 'apr': 4,
    'mei': 5,
    'juni': 6, 'jun': 6,
    'juli': 7, 'jul': 7,
    'agustus': 8, 'agu': 8, 'ags': 8,
    'september': 9, 'sep': 9,
    'oktober': 10, 'okt': 10,
    'november': 11, 'nov': 11,
    'desember': 12, 'des': 12,
  };

  static final Map<String, ChartKind> chartKindWords = <String, ChartKind>{
    'bar': ChartKind.bar,
    'batang': ChartKind.bar,
    'garis': ChartKind.line,
    'line': ChartKind.line,
    'tren': ChartKind.line,
    'trend': ChartKind.line,
    'pie': ChartKind.pie,
    'bulat': ChartKind.pie,
    'lingkaran': ChartKind.pie,
  };

  static final RegExp reDashWord = RegExp(
    r'(grafik|chart|kartu|dashboard|tampil|menampilkan|lihat|rekap|ringkasan|berapa|total|reset)',
  );
  static final RegExp reAddCard = RegExp(r'(tambah|buat|bikin)\s+(?:satu\s+)?kartu\s+(.*)');
  static final RegExp reDelCard = RegExp(r'(hapus|buang)\s+(?:satu\s+)?kartu\s+(.*)');
  static final RegExp reChangeChart = RegExp(r'(?:ubah|ganti|jadikan|set)\b.*?\b(?:grafik|chart)\b.*', caseSensitive: false);
  static final RegExp reShowRange = RegExp(r'(?:tampilkan|lihat|pamerkan)\s+(?:pengeluaran|belanja|spend)\s+(.*)', caseSensitive: false);
  static final RegExp reSummary = RegExp(r'\b(?:berapa|total|ringkasan|rekap|laporan)\b', caseSensitive: false);
  static final RegExp reResetDash = RegExp(r'reset\s+dashboard', caseSensitive: false);
  static final RegExp reNdays = RegExp(r'(\d+)\s*s?hari\s*(terakhir|lalu|belakang)', caseSensitive: false);

  static final List<RegExp> amountRegexes = <RegExp>[
    RegExp(r'(\d+)(?:[.,]\d+)?\s*(ribu|rb|k|jt|juta)\b', caseSensitive: false),
    RegExp(r'(?:rp\.?|idr)\s*(\d[\d.,]*)(?:\s*(?:ribu|rb|k|jt|juta))?', caseSensitive: false),
    RegExp(r'\b(\d[\d.,]{3,})(?!\d)\b'),
  ];

  /// Pecah perintah berisi banyak item: "kopi gold 7k, nescafe ice 1 renceng 13900"
  /// → dua bagian terpisah; dipisah koma, newline, atau " terus/trus ".
  static List<String> splitItems(String raw) {
    final text = raw
        .replaceAll('\n', ' , ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final parts = text.split(RegExp(r',|\s(?:terus|trus|abis)\s'));
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }

  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static AgentResult run(String commandRaw, List<Expense> expenses, List<CardDef> cards) {
    final command = normalize(commandRaw);
    if (command.isEmpty) return AgentInfo(helpText());

    if (reResetDash.hasMatch(command)) {
      return AgentDashboardUpdated(getDefaultDashboard(), 'Dashboard dikembalikan ke tampilan awal.');
    }

    if (reDashWord.hasMatch(command)) {
      final add = reAddCard.firstMatch(command);
      if (add != null) return buildAddCard(add.group(2)!.trim(), cards);
      final del = reDelCard.firstMatch(command);
      if (del != null) return buildDeleteCard(del.group(2)!.trim(), cards);
      if (reChangeChart.hasMatch(command)) return buildChangeChart(command, cards);
      final show = reShowRange.firstMatch(command);
      if (show != null) return buildShowRange(show.group(1)!.trim(), cards);
      if (reSummary.hasMatch(command)) return buildSummary(command, expenses);
    }

    // terakhir: coba jadi catatan pengeluaran — bisa multi-item
    final items = parseExpenseItems(commandRaw);
    if (items.isNotEmpty) {
      final expensesOut = <Expense>[];
      for (final item in items) {
        expensesOut.add(Expense.create(
          amount: item.amount,
          category: item.category,
          merchant: item.merchant,
          note: item.rawSegment,
          source: 'agent',
        ));
      }
      final detail = expensesOut
          .map((e) => '• ${e.category}: ${formatRupiah(e.amount)}'
              + (e.merchant.isNotEmpty ? ' (${e.merchant})' : ''))
          .join('\n');
      final total = expensesOut.fold(0, (sum, e) => sum + e.amount);
      return AgentRecorded(
        expensesOut,
        '${expensesOut.length == 1 ? 'Dicatat' : '${expensesOut.length} pengeluaran dicatat'} — total ${formatRupiah(total)}:\n$detail',
      );
    }

    return AgentInfo(helpText());
  }

  static String helpText() =>
      'Hmm, belum paham. Coba misalnya:\n'
      '• makan bakso 25 ribu\n'
      '• kopi gold 7k, nescafe ice 1 renceng 13900\n'
      '• ubah grafik jadi pie\n'
      '• tampilkan pengeluaran 1-7 Oktober\n'
      '• tambah kartu bar 7 hari\n'
      '• total bulan ini';

  static int? parseAmountOf(String textRaw) {
    final text = normalize(textRaw);
    for (final rx in amountRegexes) {
      final m = rx.firstMatch(text);
      if (m == null) continue;
      final digits = int.tryParse((m.group(1) ?? '').replaceAll('.', '').replaceAll(',', ''));
      if (digits == null) continue;
      final suffix = m.groupCount >= 2 ? (m.group(2) ?? '').trim() : '';
      int multiplier;
      switch (suffix) {
        case 'ribu':
        case 'rb':
        case 'k':
          multiplier = 1000;
          break;
        case 'jt':
        case 'juta':
          multiplier = 1000000;
          break;
        case '':
          multiplier = digits < 100 ? 1000 : 1;
          break;
        default:
          multiplier = 1;
      }
      return digits * multiplier;
    }
    return null;
  }

  /// Nominal Mayor: sizeable numbers like "13900" or "13900,00" also fine.
  static bool looksLikeAmount(String text) => parseAmountOf(text) != null;

  /// Pecahkan satu perintah jadi beberapa pengeluaran (multi-item).
  static List<ParsedItem> parseExpenseItems(String raw) {
    final out = <ParsedItem>[];
    for (final segment in splitItems(raw)) {
      final amount = parseAmountOf(segment);
      if (amount == null || amount <= 0) continue;
      final cat = guessCategoryAndMerchant(segment);
      out.add(ParsedItem(amount: amount, category: cat.$1, merchant: cat.$2, rawSegment: segment));
    }
    return out;
  }

  static (String, String) guessCategoryAndMerchant(String textRaw) {
    final text = normalize(textRaw);
    var category = 'Lainnya';
    var bestScore = 0;
    categoryKeywords.forEach((cat, keys) {
      final score = keys.where((k) => text.contains(k)).length;
      if (score > bestScore) {
        bestScore = score;
        category = cat;
      }
    });

    var merchant = text
        .replaceAll(RegExp(r'(?:rp\.?|idr)\s*\d[\d.,]*'), ' ')
        .replaceAll(RegExp(r'\d[\d.,]{3,}'), ' ')
        .replaceAll(RegExp(r'\d+\s*(?:ribu|rb|k|jt|juta)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[^a-z\s-]'), ' ');
    final words = merchant
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .where((w) => !_stopWords.contains(w))
        .map((w) => w.isEmpty ? w : w.substring(0, 1).toUpperCase() + w.substring(1))
        .toList();
    merchant = words.join(' ');
    if (merchant.length > 40) merchant = merchant.substring(0, 40).trim();
    if (merchant.isEmpty) merchant = category;
    return (category, merchant);
  }

  static const Set<String> _stopWords = <String>{
    'catat', 'catatkan', 'belanja', 'beli', 'bayar', 'tadi', 'habis', 'sudah',
    'saya', 'aku', 'gue', 'gua', 'gw', 'makan', 'pengeluaran', 'buat', 'pake',
    'pakai', 'uang', 'jajan',
  };

  static ChartKind? chartKindOf(String text) {
    for (final entry in chartKindWords.entries) {
      final rx = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
      if (rx.hasMatch(text)) return entry.value;
    }
    return null;
  }

  static String chartLabel(ChartKind kind) {
    switch (kind) {
      case ChartKind.bar:
        return 'bar';
      case ChartKind.line:
        return 'line (garis)';
      case ChartKind.pie:
        return 'pie (bulat)';
    }
  }

  /// Rentang tanggal dari teks: "bulan ini", "1-7 Oktober", "7 hari terakhir", dll.
  static (DateTime, DateTime, String)? parseDateRange(String textRaw) {
    final text = normalize(textRaw);
    final today = DateTime.now();
    DateTime dateOnly(int y, int m, int d) => DateTime(y, m, d, 12);

    final nd = reNdays.firstMatch(text);
    if (nd != null) {
      final n = int.tryParse(nd.group(1) ?? '30') ?? 30;
      final from = today.subtract(Duration(days: n - 1));
      return (from, today, '$n hari terakhir');
    }
    if (RegExp(r'\b(?:hari\s+ini)\b').hasMatch(text)) {
      return (today, today, 'Hari ini');
    }
    if (RegExp(r'\b(?:kemarin|kemaren)\b').hasMatch(text)) {
      final y = today.subtract(const Duration(days: 1));
      return (y, y, 'Kemarin');
    }
    if (RegExp(r'\b(?:minggu\s*ini)\b').hasMatch(text)) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return (monday, today, 'Minggu ini');
    }
    if (RegExp(r'\b(?:bulan\s+lalu|bulan\s+kemarin)\b').hasMatch(text)) {
      final first = DateTime(today.year, today.month - 1, 1);
      final last = DateTime(first.year, first.month + 1, 0);
      return (first, last, '${monthLabel(first.month)} lalu');
    }
    if (RegExp(r'\b(?:bulan\s*ini)\b').hasMatch(text)) {
      final first = DateTime(today.year, today.month, 1);
      return (first, today, '${monthLabel(today.month)} ini');
    }
    if (RegExp(r'\b(?:tahun\s*ini)\b').hasMatch(text)) {
      final first = DateTime(today.year, 1, 1);
      return (first, today, 'Tahun ini');
    }

    final range = RegExp(
      r'(\d{1,2})(?:\s*(?:s\/|sd|smp|sampe|sampai|-|ke)\s*(\d{1,2}))?\s*'
      r'(jan(?:uari)?|feb(?:ruari)?|maret|mar|april|apr|mei|juni|jun|juli|jul|agustus|agu|ags|september|sep|oktober|okt|november|nov|desember|des)'
      r'(?:\s+(\d{4}))?',
      caseSensitive: false,
    ).firstMatch(text);
    if (range != null) {
      final dayFrom = int.tryParse(range.group(1) ?? '');
      final dayToRaw = int.tryParse(range.group(2) ?? '') ?? dayFrom;
      final month = monthNames[range.group(3)?.trim()];
      final yearValue = int.tryParse(range.group(4) ?? '') ?? today.year;
      if (dayFrom == null) return null;
      if (month == null) return null;
      if (month < 1 || month > 12) return null;
      try {
        final from = dateOnly(yearValue, month, dayFrom);
        final to = dateOnly(yearValue, month, dayToRaw ?? dayFrom);
        if (to.isBefore(from)) {
          final from2 = to.subtract(const Duration(days: 6));
          return (from2, to, '${pretty(from2)} – ${pretty(to)}');
        }
        return (from, to, from == to ? pretty(from) : '${pretty(from)} – ${pretty(to)}');
      } catch (_) {
        return null;
      }
    }

    final isoMatches = RegExp(r'\d{4}-\d{2}-\d{2}').allMatches(text).toList();
    if (isoMatches.length >= 2) {
      final f = DateTime.tryParse(isoMatches[0].group(0)!);
      final t = DateTime.tryParse(isoMatches[1].group(0)!);
      if (f != null && t != null) {
        return (f, t, f == t ? pretty(f) : '${pretty(f)} – ${pretty(t)}');
      }
    }
    if (isoMatches.length == 1) {
      final d = DateTime.tryParse(isoMatches[0].group(0)!);
      if (d != null) return (d, d, pretty(d));
    }
    return null;
  }

  static String monthLabel(int month) => const [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
        'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ][month];

  static String pretty(DateTime d) => '${d.day} ${monthLabel(d.month)}';

  static AgentResult buildChangeChart(String command, List<CardDef> cards) {
    final kind = chartKindOf(command);
    if (kind == null) {
      return AgentInfo('Ke tipe apa? bar, line/garis, atau pie/bulat?');
    }
    final updated = cards.map((c) => c.type == 'chart' ? c.copyWith(chartKind: kind) : c).toList();
    return AgentDashboardUpdated(updated, 'Semua kartu grafik diubah ke ${chartLabel(kind)}.');
  }

  static AgentResult buildShowRange(String rest, List<CardDef> cards) {
    final kind = chartKindOf(rest);
    final range = parseDateRange(rest);
    if (range != null) {
      final (from, to, label) = range;
      final newCard = CardDef.create(
        type: 'chart',
        title: 'Pengeluaran $label',
        chartKind: kind ?? ChartKind.bar,
        startDate: iso(from),
        endDate: iso(to),
      );
      final remaining = cards.where((c) => !(c.startDate == iso(from) && c.endDate == iso(to))).toList();
      return AgentDashboardUpdated(remaining + [newCard], 'Kartu grafik $label ditambahkan.');
    }
    final days = int.tryParse(RegExp(r'\b(\d+)\b').firstMatch(rest)?.group(1) ?? '') ?? 30;
    final newCard = CardDef.create(
      type: 'chart',
      title: 'Trend terakhir $days hari',
      chartKind: kind ?? ChartKind.bar,
      days: days,
    );
    return AgentDashboardUpdated(cards + [newCard], 'Kartu trend $days hari ditambahkan.');
  }

  static String iso(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String().substring(0, 10);

  static AgentResult buildAddCard(String rest, List<CardDef> cards) {
    final kind = chartKindOf(rest);
    final range = parseDateRange(rest);
    final days = int.tryParse(RegExp(r'\b(\d+)\b').firstMatch(rest)?.group(1) ?? '') ?? 30;

    CardDef card;
    if (kind != null) {
      card = CardDef.create(
        type: 'chart',
        title: 'Grafik ' + (range != null ? range.$3 : 'terakhir $days hari'),
        chartKind: kind,
        days: days,
        startDate: range != null ? iso(range.$1) : null,
        endDate: range != null ? iso(range.$2) : null,
      );
    } else if (RegExp(r'\b(?:kategori|top)\b').hasMatch(rest)) {
      card = CardDef.create(
        type: 'category',
        title: 'Kategori ' + (range != null ? range.$3 : 'terakhir $days hari'),
        days: days,
        startDate: range != null ? iso(range.$1) : null,
        endDate: range != null ? iso(range.$2) : null,
      );
    } else if (RegExp(r'\b(?:transaksi|riwayat|list)\b').hasMatch(rest)) {
      card = CardDef.create(
        type: 'list',
        title: 'Transaksi ' + (range != null ? range.$3 : 'terakhir $days hari'),
        days: days,
        startDate: range != null ? iso(range.$1) : null,
        endDate: range != null ? iso(range.$2) : null,
      );
    } else if (range != null) {
      card = CardDef.create(
        type: 'total',
        title: 'Total ' + range.$3,
        days: days,
        startDate: iso(range.$1),
        endDate: iso(range.$2),
      );
    } else {
      card = CardDef.create(type: 'total', title: 'Total terakhir $days hari', days: days);
    }
    return AgentDashboardUpdated(cards + [card], 'Kartu baru: ${card.title}');
  }

  static AgentResult buildDeleteCard(String rest, List<CardDef> cards) {
    final lower = normalize(rest);
    final keyword = lower.split(' ').first.trim();
    if (keyword.isEmpty) return AgentInfo('Kartu mana yang mau dihapus? Misal: hapus kartu pie.');
    final targets = cards
        .where((c) => normalize(c.title).contains(keyword) || c.chartKind.name == keyword || c.type == keyword)
        .toList();
    if (targets.isEmpty) return AgentInfo('Tidak ada kartu yang cocok dengan "$rest".');
    final remaining = cards.where((c) => !targets.contains(c)).toList();
    if (remaining.isEmpty) return AgentInfo('Dashboard tidak bisa kosong — sisakan minimal 1 kartu.');
    return AgentDashboardUpdated(remaining, 'Kartu "$keyword" dihapus.');
  }

  static AgentResult buildSummary(String command, List<Expense> expenses) {
    final range = parseDateRange(command) ??
        (
          DateTime(DateTime.now().year, DateTime.now().month, 1),
          DateTime.now(),
          '${monthLabel(DateTime.now().month)} ini',
        );
    final (from, to, label) = range;
    final fromKey = iso(from);
    final toKey = iso(to);
    final list = expenses
        .where((e) => e.dateKey.compareTo(fromKey) >= 0 && e.dateKey.compareTo(toKey) <= 0)
        .toList();
    if (list.isEmpty) return AgentInfo('Belum ada pengeluaran di periode $label.');
    final total = list.fold(0, (sum, e) => sum + e.amount);
    final catTotals = <String, int>{};
    for (final e in list) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final entries = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(3).map((e) => '• ${e.key}: ${formatRupiah(e.value)}').join('\n');
    return AgentInfo('Total $label: ${formatRupiah(total)} dari ${list.length} transaksi.\nKategori terbesar:\n$top');
  }

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Parser notifikasi: kembalikan (amount, merchant) kalau ada nominal.
  static (int, String)? parseNotification(String title, String text) {
    final amount = parseAmountOf('$title $text');
    if (amount == null || amount <= 0) return null;
    final merchantRaw = title
        .replaceAll(RegExp(r'(?:rp\.?|idr)\s*\d[\d.,]*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\d[\d.,]{3,}'), ' ')
        .replaceAll(RegExp(r'[^A-Za-z\s-]'), ' ')
        .trim();
    final merchant = merchantRaw
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.isEmpty ? w : w.substring(0, 1).toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
    return (amount, merchant);
  }

  static String guessNotifCategory(String fullText) => guessCategoryAndMerchant(fullText).$1;
}

class ParsedItem {
  final int amount;
  final String category;
  final String merchant;
  final String rawSegment;

  const ParsedItem({required this.amount, required this.category, required this.merchant, required this.rawSegment});
}
