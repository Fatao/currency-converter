import 'dart:async';
import 'dart:convert';

import 'package:currency_converter/api_client.dart';
import 'package:currency_converter/currency_repository.dart';
import 'package:currency_converter/exchange_rate.dart';
import 'package:currency_converter/formatting.dart';
import 'package:currency_converter/rate_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _erApiBody = '''
{"result":"success","base_code":"EUR","time_last_update_unix":1792368152,
 "rates":{"EUR":1,"RUB":93.876993,"USD":1.122511}}
''';

const _cdnBody = '{"date":"2026-10-19","eur":{"rub":94.58,"usd":1.12}}';

http.Response _json(String body, [int status = 200]) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

ApiClient _api(MockClientHandler handler) =>
    ApiClient(client: MockClient(handler), timeout: const Duration(seconds: 1));

void main() {
  group('ExchangeRate.fromErApiJson', () {
    test('разбирает ответ и курс', () {
      final rate = ExchangeRate.fromErApiJson(
        jsonDecode(_erApiBody) as Map<String, dynamic>,
      );
      expect(rate.base, 'EUR');
      expect(rate.rateTo('rub'), 93.876993);
      expect(rate.updatedAt, DateTime.utc(2026, 10, 19, 0, 2, 32));
    });

    test('result=error → FormatException', () {
      expect(
        () => ExchangeRate.fromErApiJson({'result': 'error', 'error-type': 'x'}),
        throwsFormatException,
      );
    });

    test('нет поля rates → FormatException', () {
      expect(
        () => ExchangeRate.fromErApiJson({
          'result': 'success',
          'base_code': 'EUR',
          'time_last_update_unix': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('ExchangeRate.fromCdnJson', () {
    test('разбирает ответ резервного источника', () {
      final rate = ExchangeRate.fromCdnJson(
        jsonDecode(_cdnBody) as Map<String, dynamic>,
        'EUR',
      );
      expect(rate.rateTo('RUB'), 94.58);
      expect(rate.hasTime, isFalse);
    });
  });

  group('ApiClient', () {
    test('успешный ответ → модель', () async {
      final rate = await _api((_) async => _json(_erApiBody)).fetchPrimary('EUR');
      expect(rate.rateTo('USD'), 1.122511);
    });

    test('HTTP 500 → ApiErrorType.server', () async {
      expect(
        _api((_) async => _json('oops', 500)).fetchPrimary('EUR'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.server)),
      );
    });

    test('HTTP 429 → rateLimited', () async {
      expect(
        _api((_) async => _json('', 429)).fetchPrimary('EUR'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.rateLimited)),
      );
    });

    test('не JSON → badResponse', () async {
      expect(
        _api((_) async => _json('<html>')).fetchPrimary('EUR'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.badResponse)),
      );
    });

    test('сетевая ошибка → noConnection', () async {
      expect(
        _api((_) async => throw http.ClientException('no network')).fetchPrimary('EUR'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.noConnection)),
      );
    });

    test('долгий ответ → timeout', () async {
      final api = ApiClient(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 50),
      );
      expect(
        api.fetchPrimary('EUR'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.timeout)),
      );
    });
  });

  group('CurrencyRepository', () {
    test('основной источник работает → курс сохраняется в кэш', () async {
      final cache = MemoryRateCache();
      final repo = CurrencyRepository(
        api: _api((_) async => _json(_erApiBody)),
        cache: cache,
      );
      final rate = await repo.getRates('EUR');

      expect(rate.fromCache, isFalse);
      expect(await cache.load('EUR'), isNotNull);
    });

    test('основной упал → берётся резервный', () async {
      final repo = CurrencyRepository(
        api: _api((request) async {
          if (request.url.host == 'open.er-api.com') return _json('', 500);
          return _json(_cdnBody);
        }),
        cache: MemoryRateCache(),
      );
      final rate = await repo.getRates('EUR');

      expect(rate.rateTo('RUB'), 94.58);
    });

    test('оба источника упали → курс из кэша с пометкой', () async {
      final cache = MemoryRateCache();
      await cache.save(ExchangeRate(
        base: 'EUR',
        rates: const {'RUB': 90},
        updatedAt: DateTime.utc(2026, 10, 18),
      ));
      final repo = CurrencyRepository(
        api: _api((_) async => throw http.ClientException('offline')),
        cache: cache,
      );
      final rate = await repo.getRates('EUR');

      expect(rate.fromCache, isTrue);
      expect(rate.rateTo('RUB'), 90);
    });

    test('оба упали и кэша нет → ошибка', () async {
      final repo = CurrencyRepository(
        api: _api((_) async => throw http.ClientException('offline')),
        cache: MemoryRateCache(),
      );
      expect(repo.getRates('EUR'), throwsA(isA<ApiException>()));
    });
  });

  group('форматирование', () {
    test('formatMoney группирует тысячи', () {
      expect(formatMoney(9387.6993), '9 387,70');
      expect(formatMoney(0), '0,00');
    });

    test('formatRate подбирает точность', () {
      expect(formatRate(93.876993), '93,8770');
      expect(formatRate(0.01065), '0,010650');
    });
  });
}