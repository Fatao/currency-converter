import 'api_client.dart';
import 'exchange_rate.dart';
import 'rate_cache.dart';

/// Откуда приложение берёт курсы. Состояние зависит от этого интерфейса,
/// поэтому в тестах его легко заменить поддельным.
abstract class RatesRepository {
  Future<ExchangeRate> getRates(String base);
}

/// Решает, где взять курс:
/// 1) основной источник → 2) резервный источник → 3) последний сохранённый курс.
class CurrencyRepository implements RatesRepository {
  CurrencyRepository({required ApiClient api, required RateCache cache})
      : _api = api,
        _cache = cache;

  final ApiClient _api;
  final RateCache _cache;

  @override
  Future<ExchangeRate> getRates(String base) async {
    // Если не получится ничего, пользователю покажем ошибку основного источника.
    ApiException firstError = const ApiException(
      ApiErrorType.noConnection,
      'Не удалось получить курс.',
    );

    try {
      return await _fetchAndStore(() => _api.fetchPrimary(base));
    } on ApiException catch (e) {
      firstError = e;
    }

    try {
      return await _fetchAndStore(() => _api.fetchBackup(base));
    } on ApiException {
      // Оба источника недоступны — пробуем кэш.
    }

    final cached = await _cache.load(base);
    if (cached != null) {
      return cached.copyWith(fromCache: true);
    }
    throw firstError;
  }

  Future<ExchangeRate> _fetchAndStore(
    Future<ExchangeRate> Function() fetch,
  ) async {
    final rate = await fetch();
    await _cache.save(rate);
    return rate;
  }
}
