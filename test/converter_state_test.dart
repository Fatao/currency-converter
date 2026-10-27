import 'package:currency_converter/api_client.dart';
import 'package:currency_converter/converter_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeRepository repo;
  late ConverterState state;

  setUp(() {
    repo = FakeRepository();
    state = ConverterState(repo);
  });

  test('100 EUR -> RUB по известному курсу даёт 10000', () async {
    state.setAmountText('100');
    await state.convert();

    expect(state.status, ConvertStatus.success);
    expect(state.result, 10000);
    expect(state.rate, 100);
    expect(state.updatedAt, isNotNull);
  });

  test('запятая как десятичный разделитель принимается', () async {
    state.setAmountText('1,5');
    await state.convert();

    expect(state.result, 150);
  });

  test('пустая сумма: ошибка ввода, запроса нет', () async {
    state.setAmountText('   ');
    await state.convert();

    expect(state.inputError, 'Введите сумму');
    expect(state.status, ConvertStatus.idle);
    expect(repo.requestedBases, isEmpty);
  });

  test('не число: ошибка ввода, запроса нет', () async {
    state.setAmountText('abc');
    await state.convert();

    expect(state.inputError, isNotNull);
    expect(repo.requestedBases, isEmpty);
  });

  test('отрицательная сумма отклоняется', () async {
    state.setAmountText('-5');
    await state.convert();

    expect(state.inputError, 'Сумма не может быть отрицательной');
    expect(repo.requestedBases, isEmpty);
  });

  test('слишком большая сумма отклоняется', () async {
    state.setAmountText('1e15');
    await state.convert();

    expect(state.inputError, 'Слишком большая сумма');
  });

  test('ноль — допустимая сумма', () async {
    state.setAmountText('0');
    await state.convert();

    expect(state.status, ConvertStatus.success);
    expect(state.result, 0);
  });

  test('нет интернета: состояние error с понятным сообщением', () async {
    repo.error = const ApiException(
      ApiErrorType.noConnection,
      'Нет подключения к интернету.',
    );
    state.setAmountText('100');
    await state.convert();

    expect(state.status, ConvertStatus.error);
    expect(state.errorMessage, 'Нет подключения к интернету.');
    expect(state.result, isNull);
  });

  test('ошибка сервера: состояние error', () async {
    repo.error = const ApiException(ApiErrorType.server, 'Ошибка сервера (код 500).');
    state.setAmountText('100');
    await state.convert();

    expect(state.status, ConvertStatus.error);
    expect(state.errorMessage, contains('500'));
  });

  test('после ошибки повторная попытка может завершиться успехом', () async {
    repo.error = const ApiException(ApiErrorType.timeout, 'Таймаут');
    state.setAmountText('100');
    await state.convert();
    expect(state.status, ConvertStatus.error);

    repo.error = null;
    await state.convert();
    expect(state.status, ConvertStatus.success);
  });

  test('swap меняет направление: RUB -> EUR', () async {
    state.setAmountText('100');
    await state.convert();
    expect(state.resultFrom, 'EUR');
    expect(state.resultTo, 'RUB');

    await state.swap();

    expect(state.from, 'RUB');
    expect(state.to, 'EUR');
    expect(state.resultFrom, 'RUB');
    expect(state.resultTo, 'EUR');
    expect(state.result, closeTo(1, 1e-9)); // 100 RUB * 0.01
  });

  test('swap до первого расчёта только меняет валюты', () async {
    await state.swap();

    expect(state.from, 'RUB');
    expect(state.to, 'EUR');
    expect(repo.requestedBases, isEmpty);
  });

  test('смена валюты сбрасывает старый результат', () async {
    state.setAmountText('100');
    await state.convert();
    expect(state.status, ConvertStatus.success);

    state.setTo('USD');

    expect(state.status, ConvertStatus.idle);
    expect(state.result, isNull);
  });

  test('во время запроса показывается loading', () async {
    state.setAmountText('100');
    final future = state.convert();

    expect(state.status, ConvertStatus.loading);
    await future;
    expect(state.status, ConvertStatus.success);
  });
}
