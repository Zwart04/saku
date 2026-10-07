import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'saku_channel.dart';

class SakuStore {
  SharedPreferences? _prefs;

  static const String kExpensesFile = 'expenses.json';
  static const String kPendingFile = 'pending.json';
  static const String kDashboardFile = 'dashboard.json';
  static const String kExportFile = 'money_agent_export.csv';

  Future<SharedPreferences> _p() async => _prefs ??= await SharedPreferences.getInstance();

  Future<bool> get onboarded async => (await _p()).getBool('onboarded') ?? false;

  Future<void> setOnboarded(bool v) async => (await _p()).setBool('onboarded', v);

  Future<bool> get autoAddNotifications async => (await _p()).getBool('auto_add') ?? false;

  Future<void> setAutoAddNotifications(bool v) async => (await _p()).setBool('auto_add', v);

  /// Cek langsung ke native (akses notifikasi bisa berubah dari luar aplikasi).
  Future<bool> notifAccessGranted() => SakuChannel.notifAccessGranted();

  Future<String> folderNameText() async {
    final name = await SakuChannel.folderName();
    return name ?? '(belum ada)';
  }

  Future<bool> ensureFolder() async {
    if (!await SakuChannel.folderReady()) return false;
    return SakuChannel.ensureFiles();
  }

  Future<bool> bootstrapFromFolder() => ensureFolder();
}

/// Perekam data pengeluaran — jembatan FolderStore (native SAF) + JSON.
class SakuRepo {
  final SakuStore store;

  SakuRepo(this.store);

  Future<List<Expense>> expenses() async {
    final raw = await SakuChannel.readFile(SakuStore.kExpensesFile) ?? '';
    final list = JsonSerde.expensesFromJson(raw);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<bool> add(Expense e) async {
    final list = await expenses();
    list.insert(0, e);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return SakuChannel.writeFile(SakuStore.kExpensesFile, JsonSerde.expensesToJson(list));
  }

  Future<bool> addMany(List<Expense> more) async {
    final list = await expenses();
    list.insertAll(0, more);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return SakuChannel.writeFile(SakuStore.kExpensesFile, JsonSerde.expensesToJson(list));
  }

  Future<bool> remove(String id) async {
    final list = await expenses();
    final out = list.where((e) => e.id != id).toList();
    return SakuChannel.writeFile(SakuStore.kExpensesFile, JsonSerde.expensesToJson(out));
  }

  Future<List<PendingExpense>> pending() async {
    final raw = await SakuChannel.readFile(SakuStore.kPendingFile) ?? '';
    final list = JsonSerde.pendingsFromJson(raw);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> addPending(PendingExpense p) async {
    final list = await pending();
    if (list.any((x) => x.rawText == p.rawText && x.amount == p.amount)) return;
    list.insert(0, p);
    await SakuChannel.writeFile(SakuStore.kPendingFile, JsonSerde.pendingsToJson(list));
  }

  Future<void> acceptPending(String id) async {
    final list = await pending();
    final matches = list.where((x) => x.id == id).toList();
    if (matches.isEmpty) return;
    final p = matches.first;
    await add(Expense.create(
      amount: p.amount,
      category: p.category,
      merchant: p.merchant,
      note: p.rawText,
      source: p.source,
      timestamp: p.timestamp,
    ));
    final out = list.where((x) => x.id != id).toList();
    await SakuChannel.writeFile(SakuStore.kPendingFile, JsonSerde.pendingsToJson(out));
  }

  Future<void> rejectPending(String id) async {
    final list = await pending();
    final out = list.where((x) => x.id != id).toList();
    await SakuChannel.writeFile(SakuStore.kPendingFile, JsonSerde.pendingsToJson(out));
  }

  Future<List<CardDef>> dashboard() async {
    final raw = await SakuChannel.readFile(SakuStore.kDashboardFile) ?? '';
    final cards = JsonSerde.cardsFromJson(raw);
    if (cards.isEmpty) return getDefaultDashboard();
    return cards;
  }

  Future<bool> saveDashboard(List<CardDef> cards) =>
      SakuChannel.writeFile(SakuStore.kDashboardFile, JsonSerde.cardsToJson(cards));

  Future<List<Expense>> inCardRange(List<Expense> all, CardDef card) async {
    DateTime today = DateTime.now();
    DateTime from;
    DateTime to;
    if (card.startDate != null && card.endDate != null) {
      from = DateTime.tryParse(card.startDate!) ?? today.subtract(const Duration(days: 29));
      to = DateTime.tryParse(card.endDate!) ?? today;
    } else {
      from = today.subtract(Duration(days: card.days - 1));
      to = today;
    }
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return all.where((e) {
      final d = e.timestampDate;
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();
  }

  Future<bool> exportCsv() async {
    final list = await expenses();
    final sorted = list.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (!await SakuChannel.exists(SakuStore.kExportFile)) {
      await SakuChannel.appendCsv(SakuStore.kExportFile, 'tanggal,jumlah,kategori,merchant,catatan,sumber');
    }
    for (final e in sorted) {
      final row = <String>[
        e.dateKey,
        '${e.amount}',
        _csv(e.category),
        _csv(e.merchant),
        _csv(e.note),
        _csv(e.source),
      ].join(',');
      await SakuChannel.appendCsv(SakuStore.kExportFile, row);
    }
    return true;
  }

  String _csv(String v) => '"' + v.replaceAll('"', "'") + '"';

  Future<int> totalToday() async {
    final all = await expenses();
    final todayStart = DateTime.now();
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day);
    var sum = 0;
    for (final e in all) {
      if (!e.timestampDate.isBefore(start)) {
        sum += e.amount;
      }
    }
    return sum;
  }
}
