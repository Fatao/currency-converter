import 'package:currency_converter/api_client.dart';
import 'package:currency_converter/currency_repository.dart';
import 'package:currency_converter/exchange_rate.dart';

/// Поддельный репозиторий: возвращает заранее заданный курс или ошибку.
class FakeRepository implements RatesRepository {
  FakeRepository({this.error});

  ApiException? error;
  final List<String> requestedBases = [];

  /// Известные курсы: 1 EUR = 100 RUB, 1 RUB = 0.01 EUR.
  static final Map<String, Map<String, double>> table = {
    'EUR': {'EUR': 1, 'RUB': 100, 'USD': 1.2},
    'RUB': {'RUB': 1, 'EUR': 0.01, 'USD': 0.012},
    'USD': {'USD': 1, 'EUR': 0.8, 'RUB': 80},
  };

  @override
  Future<ExchangeRate> getRates(String base) async {
    requestedBases.add(base);
    final e = error;
    if (e != null) throw e;
    return ExchangeRate(
      base: base,
      rates: table[base]!,
      updatedAt: DateTime.utc(2026, 10, 19, 0, 2),
    );
  }
}
