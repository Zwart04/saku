import 'package:flutter_test/flutter_test.dart';

import 'package:saku/agent.dart';
import 'package:saku/models.dart';

void main() {
  test('smoke: model & agent dasar', () {
    final e = Expense.create(
      amount: 15000,
      category: 'Makanan',
      merchant: 'Warung',
      note: '',
      source: 'manual',
    );
    expect(e.amount, 15000);
    expect(formatRupiah(15000), 'Rp15.000');
    expect(MoneyAgent.parseAmountOf('kopi 12k'), 12000);
  });
}
