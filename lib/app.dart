import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agent.dart';
import 'mascot.dart';
import 'models.dart';
import 'ocr.dart';
import 'onboarding.dart';
import 'quick_add.dart';
import 'saku_channel.dart';
import 'store.dart';
import 'tabs.dart';
import 'theme.dart';
import 'voice.dart';

class SakuRoot extends StatefulWidget {
  final SakuStore store;
  final SakuRepo repo;

  const SakuRoot({super.key, required this.store, required this.repo});

  @override
  State<SakuRoot> createState() => _SakuRootState();
}

class _SakuRootState extends State<SakuRoot> {
  int tab = 0;
  bool ready = false;
  List<Expense> expenses = <Expense>[];
  List<PendingExpense> pendings = <PendingExpense>[];
  List<CardDef> cards = <CardDef>[];
  List<ChatMessage> chats = <ChatMessage>[];
  String status = '';
  bool notifOk = false;
  bool autoAdd = false;
  bool listening = false;

  StreamSubscription<Object?>? _notifSub;
  StreamSubscription<String>? _voiceSub;
  StreamSubscription<String>? _voiceErrSub;
  final VoiceHelper voice = VoiceHelper();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _voiceSub?.cancel();
    _voiceErrSub?.cancel();
    voice.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final ok = await widget.store.bootstrapFromFolder();
    await refreshData();
    final notif = await widget.store.notifAccessGranted();
    final auto = await widget.store.autoAddNotifications;
    final onboarded = await widget.store.onboarded;

    // Salam pembuka di tab agent + draft-kopi awal
    setState(() {
      chats = <ChatMessage>[
        const ChatMessage(
          true,
          'Hai, aku Saku! Titip pengeluaranmu ke aku, misal: "makan bakso 25 ribu". '
          'Bisa multi item juga: "kopi gold 7k, nescafe ice 1 renceng 13900".',
        ),
      ];
    });

    _notifSub = SakuChannel.notifStream.receiveBroadcastStream().listen(
      (Object? event) => _handleNotifEvent(event),
      onError: (Object? e) {},
    );

    _voiceSub = voice.results.listen((String text) {
      if (!mounted) return;
      setState(() => listening = false);
      _runAgent(text);
    });
    _voiceErrSub = voice.errors.listen((String text) {
      if (!mounted) return;
      setState(() {
        listening = false;
        status = text;
      });
    });

    if (!mounted) return;
    setState(() {
      notifOk = notif;
      autoAdd = auto;
      ready = ok;
    });

    if (!onboarded) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (BuildContext _) => OnboardingGate(
            store: widget.store,
            onDone: (List<String> whitelist) async {
              await SakuChannel.setWhitelist(whitelist);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('onboarded', true);
              if (mounted) {
                setState(() => tab = 0);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> refreshData() async {
    final List<Expense> e = await widget.repo.expenses();
    final List<PendingExpense> p = await widget.repo.pending();
    final List<CardDef> c = await widget.repo.dashboard();
    if (!mounted) return;
    setState(() {
      expenses = e;
      pendings = p;
      cards = c;
    });
    await SakuChannel.updateWidget(_totalToday());
  }

  int _totalToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return expenses
        .where((e) => !e.timestampDate.isBefore(start))
        .fold(0, (sum, e) => sum + e.amount);
  }

  Future<void> _handleNotifEvent(Object? raw) async {
    if (raw is! Map) return;
    final evt = raw.cast<String, Object?>();
    final pkg = evt['package']?.toString() ?? '';
    final title = evt['title']?.toString() ?? '';
    final text = evt['text']?.toString() ?? '';

    final lower = '$title $text'.toLowerCase();

    final prefs = await SharedPreferences.getInstance();
    final whitelist = prefs.getStringList('notifs_whitelist') ?? <String>[];

    if (whitelist.isNotEmpty && !whitelist.contains(pkg)) return;

    final parsed = MoneyAgent.parseNotification(title, text);
    final isFinancial = _financialKeywords.any(lower.contains);
    if (parsed == null && !isFinancial) return;
    if (parsed == null) return;

    final (amount, merchant) = parsed;
    final category = MoneyAgent.guessNotifCategory('$merchant $title $text');
    final full = '$title: $text';
    final rawText = full.length > 160 ? full.substring(0, 160) : full;
    final auto = await widget.store.autoAddNotifications;

    if (auto) {
      await widget.repo.add(Expense.create(
        amount: amount,
        category: category,
        merchant: merchant,
        note: rawText,
        source: 'notification',
      ));
      if (mounted) {
        setState(() => status = 'Tercatat otomatis: ${formatRupiah(amount)} dari notifikasi.');
      }
    } else {
      await widget.repo.addPending(PendingExpense.create(
        amount: amount,
        merchant: merchant,
        category: category,
        rawText: rawText,
        source: 'notification',
      ));
      if (mounted) {
        setState(() => status = 'Notifikasi ditangkap — cek tab Konfirmasi.');
      }
    }
    await refreshData();
  }

  static const List<String> _financialKeywords = <String>[
    'transfer', 'pembayaran', 'dibayar', 'berhasil', 'debit', 'payment',
    'purchase', 'transaksi', 'deposit', 'topup', 'top up', 'saldo',
    'menerima', 'dikirim', 'gopay', 'ovo', 'dana', 'shopeepay', 'linkaja',
    'jenius', 'jago', 'bca', 'bri', 'bni', 'mandiri',
  ];

  Future<void> _runAgent(String text) async {
    if (text.trim().isEmpty || !mounted) return;
    setState(() {
      chats = chats + <ChatMessage>[ChatMessage(false, text)];
    });
    final AgentResult result = MoneyAgent.run(text, expenses, cards);
    String message = '';
    if (result is AgentRecorded) {
      await widget.repo.addMany(result.expenses);
      message = result.message;
    } else if (result is AgentDashboardUpdated) {
      await widget.repo.saveDashboard(result.cards);
      message = result.message;
    } else if (result is AgentInfo) {
      message = result.message;
    }
    await refreshData();
    if (!mounted) return;
    setState(() {
      chats = chats + <ChatMessage>[ChatMessage(true, message)];
    });
  }

  void _startVoice() {
    setState(() => listening = true);
    voice.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Mascot(
              mood: listening ? Mood.listening : (pendings.isNotEmpty ? Mood.idle : Mood.idle),
              size: 38,
            ),
            const SizedBox(width: 10),
            const Text('Halo, aku Saku!'),
          ],
        ),
      ),
      body: _body(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.warmDeep,
        onPressed: _showQuickAdd,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: <Widget>[
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Dasbor'),
          const NavigationDestination(icon: Icon(Icons.send_outlined), selectedIcon: Icon(Icons.send), label: 'Agent'),
          NavigationDestination(
            icon: _pendingBadge(Icon(Icons.notifications_outlined)),
            selectedIcon: _pendingBadge(Icon(Icons.notifications), filled: true),
            label: 'Konfirmasi',
          ),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Setelan'),
        ],
      ),
    );
  }

  Widget _body() {
    switch (tab) {
      case 0:
        return DashboardTab(
          ready: ready,
          expenses: expenses,
          pendings: pendings,
          cards: cards,
          status: status,
          onQuickAdd: _showQuickAdd,
          onAcceptPending: _acceptPending,
          onRejectPending: _rejectPending,
          onDeleteCard: _deleteCard,
        );
      case 1:
        return AgentTab(
          chats: chats,
          listening: listening,
          onSend: _runAgent,
          onVoice: _startVoice,
        );
      case 2:
        return ConfirmTab(
          pendings: pendings,
          notifOk: notifOk,
          status: status,
          onAccept: _acceptPending,
          onReject: _rejectPending,
          onOpenSettings: () async {
            await SakuChannel.openNotifAccessSettings();
            if (!mounted) return;
            final notif = await widget.store.notifAccessGranted();
            setState(() => notifOk = notif);
          },
        );
      default:
        return SettingsTab(
          store: widget.store,
          repo: widget.repo,
          autoAdd: autoAdd,
          notifOk: notifOk,
          status: status,
          onAutoAdd: _setAutoAdd,
          onOpenNotifSettings: () async {
            await SakuChannel.openNotifAccessSettings();
            if (!mounted) return;
            final notif = await widget.store.notifAccessGranted();
            setState(() => notifOk = notif);
          },
          onTestNotif: _sendTestNotif,
          onExportCsv: _exportCsv,
          onReload: _reload,
        );
    }
  }

  Widget _pendingBadge(Icon icon, {bool filled = false}) {
    if (pendings.isEmpty || filled) return icon;
    return Badge(
      label: Text('${pendings.length}'),
      backgroundColor: C.danger,
      child: icon,
    );
  }

  Future<void> _acceptPending(String id) async {
    await widget.repo.acceptPending(id);
    await refreshData();
  }

  Future<void> _rejectPending(String id) async {
    await widget.repo.rejectPending(id);
    await refreshData();
  }

  Future<void> _deleteCard(CardDef card) async {
    final remaining = cards.where((c) => c.id != card.id).toList();
    if (remaining.isEmpty) {
      if (mounted) {
        setState(() => status = 'Dashboard tidak boleh kosong — sisakan satu kartu.');
      }
      return;
    }
    await widget.repo.saveDashboard(remaining);
    await refreshData();
    if (mounted) setState(() => status = 'Kartu dihapus.');
  }

  Future<void> _setAutoAdd(bool v) async {
    await widget.store.setAutoAddNotifications(v);
    if (mounted) setState(() => autoAdd = v);
  }

  Future<void> _sendTestNotif() async {
    await SakuChannel.sendTestNotification();
    if (mounted) setState(() => status = 'Notif uji dikirim — lihat tab Konfirmasi.');
  }

  Future<void> _exportCsv() async {
    final ok = await widget.repo.exportCsv();
    if (mounted) {
      setState(() => status = ok ? 'CSV diekspor ke folder data kamu.' : 'Ekspor gagal — cek folder data.');
    }
  }

  Future<void> _reload() async {
    await refreshData();
    if (!mounted) return;
    setState(() {
      status = 'Data dimuat ulang.';
    });
  }

  Future<void> _showQuickAdd() async {
    final command = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: QuickAddSheet(voice: voice),
      ),
    );
    if (command == '::scan') {
      await _openScan();
    } else if (command != null && command.trim().isNotEmpty) {
      await _runAgent(command);
    }
  }

  Future<void> _openScan() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 72);
    if (picked == null || !mounted) return;
    final scanner = BillScanner();
    final lines = await scanner.scanFromPath(picked.path);
    await scanner.dispose();
    if (!mounted) return;
    final joined = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) => ScanConfirmSheet(lines: lines),
    );
    if (joined != null && mounted) {
      await _runAgent(joined);
    }
  }
}
