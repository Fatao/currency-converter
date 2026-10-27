import 'package:currency_converter/api_client.dart';
import 'package:currency_converter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> _pump(WidgetTester tester, FakeRepository repo) async {
  await tester.pumpWidget(CurrencyConverterApp(repository: repo));
}

void main() {
  testWidgets('100 EUR -> RUB показывает результат, курс и время', (tester) async {
    await _pump(tester, FakeRepository());

    await tester.enterText(find.byKey(const ValueKey('amount_field')), '100');
    await tester.tap(find.byKey(const ValueKey('convert_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('result_card')), findsOneWidget);
    expect(find.text('10 000,00 RUB'), findsOneWidget);
    expect(find.byKey(const ValueKey('rate_text')), findsOneWidget);
    expect(find.byKey(const ValueKey('updated_text')), findsOneWidget);
  });

  testWidgets('пустая сумма показывает ошибку под полем', (tester) async {
    await _pump(tester, FakeRepository());

    await tester.tap(find.byKey(const ValueKey('convert_button')));
    await tester.pump();

    expect(find.text('Введите сумму'), findsOneWidget);
    expect(find.byKey(const ValueKey('result_card')), findsNothing);
  });

  testWidgets('отрицательная сумма показывает ошибку', (tester) async {
    await _pump(tester, FakeRepository());

    await tester.enterText(find.byKey(const ValueKey('amount_field')), '-1');
    await tester.tap(find.byKey(const ValueKey('convert_button')));
    await tester.pump();

    expect(find.text('Сумма не может быть отрицательной'), findsOneWidget);
  });

  testWidgets('ошибка сети показывает карточку ошибки', (tester) async {
    final repo = FakeRepository(
      error: const ApiException(
        ApiErrorType.noConnection,
        'Нет подключения к интернету.',
      ),
    );
    await _pump(tester, repo);

    await tester.enterText(find.byKey(const ValueKey('amount_field')), '100');
    await tester.tap(find.byKey(const ValueKey('convert_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('error_card')), findsOneWidget);
    expect(find.text('Нет подключения к интернету.'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry_button')), findsOneWidget);
  });

  testWidgets('кнопка swap меняет направление и пересчитывает', (tester) async {
    await _pump(tester, FakeRepository());

    await tester.enterText(find.byKey(const ValueKey('amount_field')), '100');
    await tester.tap(find.byKey(const ValueKey('convert_button')));
    await tester.pumpAndSettle();
    expect(find.text('10 000,00 RUB'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('swap_button')));
    await tester.pumpAndSettle();

    expect(find.text('1,00 EUR'), findsOneWidget);
    expect(find.text('100,00 RUB = 1,00 EUR'), findsOneWidget);
  });
}