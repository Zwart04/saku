import 'dart:convert';

enum ChartKind { bar, line, pie }

/// Perekam ID unik sederhana — aman walau banyak item dibuat dalam satu siklus.
class SakuId {
  static int _counter = 0;
  static String next(String prefix) {
    _counter++;
    return '$prefix-$_counter-${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Satu bubble percakapan di tab Agent.
class ChatMessage {
  final bool fromAgent;
  final String text;
  const ChatMessage(this.fromAgent, this.text);
}

class Expense {
  final String id;
  final int timestamp;
  final int amount;
  final String category;
  final String merchant;
  final String note;
  final String source; // manual | agent | notification | scan

  const Expense({
    required this.id,
    required this.timestamp,
    required this.amount,
    required this.category,
    required this.merchant,
    required this.note,
    required this.source,
  });

  factory Expense.create({
    required int amount,
    required String category,
    required String merchant,
    required String note,
    required String source,
    int? timestamp,
  }) =>
      Expense(
        id: SakuId.next('e'),
        timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
        amount: amount,
        category: category,
        merchant: merchant,
        note: note,
        source: source,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'timestamp': timestamp,
        'amount': amount,
        'category': category,
        'merchant': merchant,
        'note': note,
        'source': source,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id']?.toString() ?? SakuId.next('e'),
        timestamp: j['timestamp'] is int ? j['timestamp'] as int : int.tryParse('${j['timestamp']}') ?? 0,
        amount: j['amount'] is int ? j['amount'] as int : int.tryParse('${j['amount']}') ?? 0,
        category: j['category']?.toString() ?? 'Lainnya',
        merchant: j['merchant']?.toString() ?? '',
        note: j['note']?.toString() ?? '',
        source: j['source']?.toString() ?? 'manual',
      );

  String get dateKey => dateKeyOf(timestamp);

  DateTime get timestampDate => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

class PendingExpense {
  final String id;
  final int timestamp;
  final int amount;
  final String merchant;
  final String category;
  final String rawText;
  final String source;

  const PendingExpense({
    required this.id,
    required this.timestamp,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.rawText,
    required this.source,
  });

  factory PendingExpense.create({
    required int amount,
    required String merchant,
    required String category,
    required String rawText,
    required String source,
  }) =>
      PendingExpense(
        id: SakuId.next('p'),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        amount: amount,
        merchant: merchant,
        category: category,
        rawText: rawText,
        source: source,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'timestamp': timestamp,
        'amount': amount,
        'merchant': merchant,
        'category': category,
        'rawText': rawText,
        'source': source,
      };

  factory PendingExpense.fromJson(Map<String, dynamic> j) => PendingExpense(
        id: j['id']?.toString() ?? SakuId.next('p'),
        timestamp: j['timestamp'] is int ? j['timestamp'] as int : int.tryParse('${j['timestamp']}') ?? 0,
        amount: j['amount'] is int ? j['amount'] as int : int.tryParse('${j['amount']}') ?? 0,
        merchant: j['merchant']?.toString() ?? '',
        category: j['category']?.toString() ?? 'Lainnya',
        rawText: j['rawText']?.toString() ?? '',
        source: j['source']?.toString() ?? 'notification',
      );

  DateTime get timestampDate => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

class CardDef {
  final String id;
  final String type; // total | chart | category | list
  final String title;
  final ChartKind chartKind;
  final int days;
  final String? startDate;
  final String? endDate;
  final int limit;

  const CardDef({
    required this.id,
    required this.type,
    required this.title,
    this.chartKind = ChartKind.bar,
    this.days = 30,
    this.startDate,
    this.endDate,
    this.limit = 5,
  });

  CardDef copyWith({
    String? type,
    String? title,
    ChartKind? chartKind,
    int? days,
    String? startDate,
    String? endDate,
    int? limit,
  }) =>
      CardDef(
        id: id,
        type: type ?? this.type,
        title: title ?? this.title,
        chartKind: chartKind ?? this.chartKind,
        days: days ?? this.days,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        limit: limit ?? this.limit,
      );

  String rangeLabel() =>
      (startDate != null && endDate != null) ? '$startDate s/d $endDate' : 'Terakhir $days hari';

  factory CardDef.create({
    required String type,
    required String title,
    ChartKind chartKind = ChartKind.bar,
    int days = 30,
    String? startDate,
    String? endDate,
    int limit = 5,
  }) =>
      CardDef(
        id: SakuId.next('c'),
        type: type,
        title: title,
        chartKind: chartKind,
        days: days,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'title': title,
        'chartKind': chartKind.name,
        'days': days,
        'startDate': startDate,
        'endDate': endDate,
        'limit': limit,
      };

  factory CardDef.fromJson(Map<String, dynamic> j) => CardDef(
        id: j['id']?.toString() ?? SakuId.next('c'),
        type: j['type']?.toString() ?? 'total',
        title: j['title']?.toString() ?? 'Kartu',
        chartKind: ChartKind.values.firstWhere(
          (k) => k.name == (j['chartKind']?.toString() ?? 'bar'),
          orElse: () => ChartKind.bar,
        ),
        days: j['days'] is int ? j['days'] as int : 30,
        startDate: j['startDate']?.toString(),
        endDate: j['endDate']?.toString(),
        limit: j['limit'] is int ? j['limit'] as int : 5,
      );
}

List<CardDef> getDefaultDashboard() => <CardDef>[
      CardDef.create(type: 'total', title: 'Pengeluaran bulan ini', days: 30),
      CardDef.create(type: 'chart', title: 'Trend harian — bulan ini', chartKind: ChartKind.bar, days: 30),
      CardDef.create(type: 'category', title: 'Kategori terbesar — bulan ini', days: 30),
      CardDef.create(type: 'list', title: 'Transaksi terbaru', days: 30, limit: 8),
    ];

class JsonSerde {
  static String expensesToJson(List<Expense> list) => jsonEncode(list.map((e) => e.toJson()).toList());

  static List<Expense> expensesFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Expense.fromJson((e as Map).cast<String, dynamic>())).toList();
      }
    } catch (_) {}
    return <Expense>[];
  }

  static String pendingsToJson(List<PendingExpense> list) => jsonEncode(list.map((e) => e.toJson()).toList());

  static List<PendingExpense> pendingsFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => PendingExpense.fromJson((e as Map).cast<String, dynamic>())).toList();
      }
    } catch (_) {}
    return <PendingExpense>[];
  }

  static String cardsToJson(List<CardDef> list) => jsonEncode(list.map((e) => e.toJson()).toList());

  static List<CardDef> cardsFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => CardDef.fromJson((e as Map).cast<String, dynamic>())).toList();
      }
    } catch (_) {}
    return <CardDef>[];
  }
}

String formatRupiah(int amount) {
  final negative = amount < 0;
  final s = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final remain = s.length - 1 - i;
    if (remain > 0 && remain % 3 == 0) buf.write('.');
  }
  return '${negative ? '-' : ''}Rp${buf.toString()}';
}

String dateKeyOf(int timestamp) =>
    DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String().substring(0, 10);
