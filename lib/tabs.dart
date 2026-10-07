import 'package:flutter/material.dart';

import 'charts.dart';
import 'mascot.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

class DashboardTab extends StatelessWidget {
  final bool ready;
  final List<Expense> expenses;
  final List<PendingExpense> pendings;
  final List<CardDef> cards;
  final String status;
  final VoidCallback onQuickAdd;
  final ValueChanged<String> onAcceptPending;
  final ValueChanged<String> onRejectPending;
  final ValueChanged<CardDef> onDeleteCard;

  const DashboardTab({
    super.key,
    required this.ready,
    required this.expenses,
    required this.pendings,
    required this.cards,
    required this.status,
    required this.onQuickAdd,
    required this.onAcceptPending,
    required this.onRejectPending,
    required this.onDeleteCard,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: _build(context),
    );
  }

  List<Widget> _build(BuildContext context) {
    final widgets = <Widget>[];
    if (status.isNotEmpty) {
      widgets.add(Surface(
        style: SurfaceStyle.chip,
        child: Row(
          children: [
            Mascot(size: 30, mood: Mood.happy),
            const SizedBox(width: 8),
            Expanded(child: Text(status, style: const TextStyle(fontSize: 12, color: C.inkSoft))),
          ],
        ),
      ));
    }
    for (final card in cards) {
      widgets.add(DashboardCardView(
        card: card,
        expenses: expenses,
        onDelete: () => _confirmDelete(context, card),
      ));
    }
    if (pendings.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(const Text(
        'Menunggu konfirmasi dari notifikasi',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ));
      widgets.addAll(pendings.take(5).map((p) => PendingRow(
            pending: p,
            onAccept: () => onAcceptPending(p.id),
            onReject: () => onRejectPending(p.id),
          )));
    }
    widgets.add(Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Semua catatan disimpan lokal di HP kamu. Saku tidak mengirimkan datamu ke mana pun.',
        style: TextStyle(fontSize: 11, color: C.inkSoft),
      ),
    ));
    return widgets;
  }

  Future<void> _confirmDelete(BuildContext context, CardDef card) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus kartu ini?'),
        content: Text('"${card.title}" dihapus dari dashboard. Datamu tidak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yes == true) {
      onDeleteCard(card);
    }
  }
}

enum SurfaceStyle { chip }

class Surface extends StatelessWidget {
  final SurfaceStyle style;
  final Widget child;

  const Surface({super.key, required this.child, this.style = SurfaceStyle.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEE8DF)),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class DashboardCardView extends StatelessWidget {
  final CardDef card;
  final List<Expense> expenses;
  final VoidCallback? onDelete;

  const DashboardCardView({
    super.key,
    required this.card,
    required this.expenses,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Filter rentang in card — signature is provided from repo service.
    final _LocalRange lr = _resolveRange(card, DateTime.now());
    final list = expenses.where((e) {
      final d = e.timestampDate;
      return !d.isBefore(lr.from) && !d.isAfter(lr.to);
    }).toList();
    final isHero = card.type == 'total';
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isHero ? Colors.white : C.ink,
                ),
              ),
              Text(
                card.rangeLabel(),
                style: TextStyle(
                  fontSize: 11,
                  color: isHero ? Colors.white70 : C.inkSoft,
                ),
              ),
            ],
          ),
        ),
        if (onDelete != null)
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close,
                size: 18,
                color: isHero ? Colors.white70 : C.inkSoft,
              ),
            ),
          ),
      ],
    );
    Widget body;
    switch (card.type) {
      case 'total':
        final total = list.fold(0, (a, e) => a + e.amount);
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatRupiah(total),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: Colors.white,
              ),
            ),
            Text(
              list.isEmpty
                  ? 'Belum ada pengeluaran di periode ini.'
                  : '${list.length} transaksi • tap + di bawah untuk catat',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        );
        break;
      case 'chart':
        body = ChartView(kind: card.chartKind, expenses: list);
        break;
      case 'category':
        body = ChartView(kind: ChartKind.pie, expenses: list);
        break;
      default:
        body = Column(
          children: [
            ...list.take(card.limit).map((e) => ExpenseRow(expense: e)),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Belum ada transaksi di rentang ini.', style: TextStyle(fontSize: 12, color: C.inkSoft)),
              ),
          ],
        );
    }
    return Card(
      color: isHero ? null : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: isHero ? BorderSide.none : const BorderSide(color: Color(0xFFEEE8DF)),
      ),
      child: isHero
          ? Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFB84C), Color(0xFFE8930C)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [header, const SizedBox(height: 10), body],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [header, const SizedBox(height: 8), body],
              ),
            ),
    );
  }

  _LocalRange _resolveRange(CardDef card, DateTime now) {
    DateTime from;
    DateTime to;
    if (card.startDate != null && card.endDate != null) {
      from = DateTime.tryParse(card.startDate!) ?? now.subtract(const Duration(days: 29));
      to = DateTime.tryParse(card.endDate!) ?? now;
    } else {
      from = now.subtract(Duration(days: card.days - 1));
      to = now;
    }
    return _LocalRange(
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day, 23, 59, 59),
    );
  }
}

class _LocalRange {
  final DateTime from;
  final DateTime to;
  const _LocalRange({required this.from, required this.to});
}

class ExpenseRow extends StatelessWidget {
  final Expense expense;

  const ExpenseRow({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.merchant.isNotEmpty ? expense.merchant : 'Pengeluaran',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${expense.category} • ${expense.dateKey}',
                  style: const TextStyle(fontSize: 11, color: C.inkSoft),
                ),
              ],
            ),
          ),
          Text(
            '-${formatRupiah(expense.amount)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class PendingRow extends StatelessWidget {
  final PendingExpense pending;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const PendingRow({super.key, required this.pending, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEEE8DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(formatRupiah(pending.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const Spacer(),
                Text(pending.timestampDate.toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: C.inkSoft)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${pending.merchant.isNotEmpty ? pending.merchant : 'Transaksi'} • ${pending.category}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              pending.rawText,
              style: const TextStyle(fontSize: 11, color: C.inkSoft),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onReject, child: const Text('Abaikan')),
                const SizedBox(width: 4),
                FilledButton(onPressed: onAccept, child: const Text('Catat')),
                const SizedBox(width: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AgentTab extends StatelessWidget {
  final List<ChatMessage> chats;
  final bool listening;
  final ValueChanged<String> onSend;
  final VoidCallback onVoice;

  const AgentTab({
    super.key,
    required this.chats,
    required this.listening,
    required this.onSend,
    required this.onVoice,
  });

  static const List<String> examples = <String>[
    'makan bakso 25 ribu',
    'kopi gold 7k, nescafe ice 1 renceng 13900',
    'grab 30k',
    'ubah grafik jadi pie',
    'tampilkan pengeluaran 1-7 Oktober',
    'rekap minggu ini',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length + 1,
            itemBuilder: (context, i) {
              if (i == chats.length) {
                return _exampleChips(context);
              }
              return _bubble(chats[i]);
            },
          ),
        ),
        Container(
          decoration: const BoxDecoration(color: C.cream),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          child: AgentComposer(onSend: onSend, onVoice: onVoice, listening: listening),
        ),
      ],
    );
  }

  Widget _bubble(ChatMessage m) {
    final fromAgent = m.fromAgent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: fromAgent ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: fromAgent ? Colors.white : C.warm.withOpacity(0.16),
                border: Border.all(color: fromAgent ? const Color(0xFFEEE8DF) : Colors.transparent),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(m.text, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exampleChips(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Contoh perintah', style: TextStyle(fontSize: 12, color: C.inkSoft)),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: examples.map((e) => _chip(e, () => onSend(e))).toList(),
        ),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEEE8DF)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      );
}

/// Composer dengan state sendiri supaya teks tidak hilang saat rebuild.
class AgentComposer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback onVoice;
  final bool listening;

  const AgentComposer({super.key, required this.onSend, required this.onVoice, required this.listening});

  @override
  State<AgentComposer> createState() => _AgentComposerState();
}

class _AgentComposerState extends State<AgentComposer> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _send() {
    final v = controller.text.trim();
    if (v.isEmpty) return;
    widget.onSend(v);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (v) => _send(),
            decoration: InputDecoration(
              hintText: 'Pengeluaran / perintah untuk Saku',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        IconButton(
          onPressed: widget.onVoice,
          icon: Icon(Icons.mic, color: widget.listening ? C.warmDeep : C.inkSoft),
          tooltip: 'Rekam suara',
        ),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: _send,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Icon(Icons.send),
        ),
      ],
    );
  }
}

class ConfirmTab extends StatelessWidget {
  final List<PendingExpense> pendings;
  final bool notifOk;
  final String status;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;
  final VoidCallback onOpenSettings;

  const ConfirmTab({
    super.key,
    required this.pendings,
    required this.notifOk,
    required this.status,
    required this.onAccept,
    required this.onReject,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Mascot(size: 42, mood: pendings.isEmpty ? Mood.happy : Mood.thinking),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Menunggu konfirmasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                    Text(
                      'Draft dari notifikasi HP. Belum masuk grafik sampai kamu setuju.',
                      style: TextStyle(fontSize: 12, color: C.inkSoft),
                    ),
                    TextButton(
                      onPressed: onOpenSettings,
                      child: Text(
                        notifOk ? 'Atur ulang pembaca notifikasi' : 'Aktifkan pembaca notifikasi',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: pendings.isEmpty
              ? const _Empty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: pendings.length,
                  itemBuilder: (context, i) => PendingRow(
                    pending: pendings[i],
                    onAccept: () => onAccept(pendings[i].id),
                    onReject: () => onReject(pendings[i].id),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: const [
          Mascot(size: 72, mood: Mood.happy),
          SizedBox(height: 12),
          Text('Tidak ada draft menunggu.', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Saku baru menangkap pengeluaran dari notifikasi — datamu tetap aman.', style: TextStyle(fontSize: 12, color: C.inkSoft)),
        ],
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  final SakuStore store;
  final SakuRepo repo;
  final bool autoAdd;
  final bool notifOk;
  final String status;
  final ValueChanged<bool> onAutoAdd;
  final VoidCallback onOpenNotifSettings;
  final VoidCallback onTestNotif;
  final VoidCallback onExportCsv;
  final VoidCallback onReload;

  const SettingsTab({
    super.key,
    required this.store,
    required this.repo,
    required this.autoAdd,
    required this.notifOk,
    required this.status,
    required this.onAutoAdd,
    required this.onOpenNotifSettings,
    required this.onTestNotif,
    required this.onExportCsv,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Setelan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 12),
        _folderCard(context),
        const SizedBox(height: 12),
        _notifCard(context),
        const SizedBox(height: 12),
        _exportCard(context),
        const SizedBox(height: 12),
        _repairCard(context),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Saku — asisten pengeluaran pribadi. Offline, tanpa iklan, tanpa server.',
            style: TextStyle(fontSize: 11, color: C.inkSoft),
          ),
        ),
      ],
    );
  }

  Widget _folderCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFEEE8DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Mascot(size: 38, mood: Mood.happy),
                const SizedBox(width: 12),
                const Text('Penyimpanan lokal', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Data Saku disimpan sebagai file JSON biasa di folder yang kamu pilih, jadi tetap ada walau aplikasi dibongkar. '
              'Bisa dibuka dari laptop lewat folder kembar (misal: Google Drive), multi gratis dan multi aman.',
              style: TextStyle(fontSize: 12, color: C.inkSoft),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(onPressed: onReload, child: const Text('Muat ulang data')),
                const SizedBox(width: 8),
                TextButton(onPressed: onExportCsv, child: const Text('Ekspor CSV')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFEEE8DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Mascot(size: 38, mood: notifOk ? Mood.happy : Mood.surprised),
                const SizedBox(width: 12),
                const Text('Pembaca notifikasi', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Saku membaca notifikasi Gopay/OVO/bank, menangkap nominalnya, lalu menunggu konfirmasimu '
              '— atau langsung mencatat kalau auto-add aktif. Pilih dulu mau baca yang mana di langkah pertama install.',
              style: TextStyle(fontSize: 12, color: C.inkSoft),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(notifOk ? 'Akses notifikasi aktif' : 'Akses belum aktif', style: const TextStyle(fontSize: 13)),
                const Spacer(),
                FilledButton(onPressed: onOpenNotifSettings, child: const Text('Buka setelan')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text('Langsung catat tanpa konfirmasi', style: TextStyle(fontSize: 13)),
                ),
                Switch(value: autoAdd, onChanged: onAutoAdd),
              ],
            ),
            TextButton.icon(
              onPressed: onTestNotif,
              icon: const Icon(Icons.announcement_outlined, size: 18),
              label: const Text('Kirim notifikasi uji'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFEEE8DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ekspor ke CSV', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Simpan salinan semua pengeluaran sebagai CSV di folder data — bisa dibuka di Excel atau Sheets.',
              style: TextStyle(fontSize: 12, color: C.inkSoft),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onExportCsv, child: const Text('Ekspor CSV')),
          ],
        ),
      ),
    );
  }

  Widget _repairCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFEEE8DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Minta bantuan', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Saku kirimkan petunjuk singkat kalau pembaca notifikasi bermasalah: cek "restricted settings" di menu aplikasi, dan izinkan autostart untuk MIUI/HyperOS.',
              style: TextStyle(fontSize: 12, color: C.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
