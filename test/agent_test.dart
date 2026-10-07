import 'package:flutter_test/flutter_test.dart';

import 'package:saku/agent.dart';
import 'package:saku/models.dart';

void main() {
  group('parseAmountOf', () {
    test('satuan ribu/rb/k/jt', () {
      expect(MoneyAgent.parseAmountOf('makan bakso 25 ribu'), 25000);
      expect(MoneyAgent.parseAmountOf('grab 30k'), 30000);
      expect(MoneyAgent.parseAmountOf('pelihara kucing 2 jt'), 2000000);
      expect(MoneyAgent.parseAmountOf('topup 100rb'), 100000);
    });

    test('angka polos', () {
      expect(MoneyAgent.parseAmountOf('nescafe 13900'), 13900);
      expect(MoneyAgent.parseAmountOf('Rp25.000'), 25000);
      expect(MoneyAgent.parseAmountOf('kamu menerima rp10.000 dari gopay'), 10000);
    });
  });

  group('parseExpenseItems (multi-item)', () {
    test('dua item dipisah koma', () {
      final items = MoneyAgent.parseExpenseItems('kopi gold 7k, nescafe ice 1 renceng 13900');
      expect(items.length, 2);
      expect(items[0].amount, 7000);
      expect(items[1].amount, 13900);
    });

    test('item dipisah "terus"', () {
      final items = MoneyAgent.parseExpenseItems('makan siang 15 ribu terus ojek 8k');
      expect(items.length, 2);
      expect(items[0].amount, 15000);
      expect(items[1].amount, 8000);
    });
  });

  group('run', () {
    test('catat pengeluaran makanan', () {
      final r = MoneyAgent.run('makan bakso 25 ribu', <Expense>[], getDefaultDashboard());
      expect(r, isA<AgentRecorded>());
      final rec = r as AgentRecorded;
      expect(rec.expenses.length, 1);
      expect(rec.expenses.first.category, 'Makanan');
      expect(rec.expenses.first.amount, 25000);
    });

    test('ubah grafik jadi pie', () {
      final cards = getDefaultDashboard();
      final r = MoneyAgent.run('ubah grafik jadi pie', <Expense>[], cards);
      expect(r, isA<AgentDashboardUpdated>());
      final upd = r as AgentDashboardUpdated;
      final charts = upd.cards.where((c) => c.type == 'chart');
      expect(charts.every((c) => c.chartKind == ChartKind.pie), isTrue);
    });

    test('tampilkan rentang 1-7 Oktober', () {
      final r = MoneyAgent.run('tampilkan pengeluaran 1-7 Oktober', <Expense>[], getDefaultDashboard());
      expect(r, isA<AgentDashboardUpdated>());
      final upd = r as AgentDashboardUpdated;
      final newCard = upd.cards.last;
      expect(newCard.type, 'chart');
      expect(newCard.startDate, isNotNull);
      expect(newCard.startDate!.endsWith('-10-01'), isTrue);
      expect(newCard.endDate!.endsWith('-10-07'), isTrue);
    });

    test('rekap bulan ini', () {
      final now = DateTime.now();
      final e = Expense.create(
        amount: 50000,
        category: 'Makanan',
        merchant: 'Warung',
        note: '',
        source: 'manual',
        timestamp: now.millisecondsSinceEpoch,
      );
      final r = MoneyAgent.run('total bulan ini', <Expense>[e], getDefaultDashboard());
      expect(r, isA<AgentInfo>());
      expect((r as AgentInfo).message.contains('Total'), isTrue);
      expect(r.message.contains('Makanan'), isTrue);
    });
  });

  group('parseNotification', () {
    test('notifikasi Jago/GoPay', () {
      final p = MoneyAgent.parseNotification('Jago', 'Kamu menerima Rp10.000 dari GoPay. Butuh bantuan?');
      expect(p, isNotNull);
      expect(p!.$1, 10000);
    });

    test('transfer berhasil gopay', () {
      final p = MoneyAgent.parseNotification('Transfer berhasil', 'Rp10.000 udah dikirim ke BANK JAGO Muammar');
      expect(p, isNotNull);
      expect(p!.$1, 10000);
    });
  });

  group('formatRupiah', () {
    test('pemisah ribuan', () {
      expect(formatRupiah(13900), 'Rp13.900');
      expect(formatRupiah(25000), 'Rp25.000');
      expect(formatRupiah(1200000), 'Rp1.200.000');
    });
  });
}
