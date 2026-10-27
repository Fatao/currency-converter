/// Курсы валют относительно одной базовой валюты.
///
/// Пример: base = "EUR", rates = {"RUB": 93.88, "USD": 1.12}
/// означает, что 1 EUR = 93.88 RUB.
class ExchangeRate {
  const ExchangeRate({
    required this.base,
    required this.rates,
    required this.updatedAt,
    this.hasTime = true,
    this.fromCache = false,
  });

  /// Код базовой валюты, например "EUR".
  final String base;

  /// Курсы «1 base = N валюты». Ключи — коды в верхнем регистре.
  final Map<String, double> rates;

  /// Когда источник обновил курс (всегда в UTC).
  final DateTime updatedAt;

  /// false, если источник дал только дату без времени.
  final bool hasTime;

  /// true, если курс взят из кэша, а не из сети.
  final bool fromCache;

  /// Курс «1 base = ? target». null, если такой валюты нет в ответе.
  double? rateTo(String target) => rates[target.toUpperCase()];

  ExchangeRate copyWith({bool? fromCache}) {
    return ExchangeRate(
      base: base,
      rates: rates,
      updatedAt: updatedAt,
      hasTime: hasTime,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  // ---------- Основной источник: open.er-api.com ----------
  //
  // Пример ответа:
  // {"result":"success","time_last_update_unix":1792368152,
  //  "base_code":"EUR","rates":{"EUR":1,"RUB":93.876993,...}}

  factory ExchangeRate.fromErApiJson(Map<String, dynamic> json) {
    if (json['result'] != 'success') {
      throw FormatException('Ошибка API: ${json['error-type'] ?? 'неизвестная'}');
    }
    final base = json['base_code'];
    final rawRates = json['rates'];
    final unix = json['time_last_update_unix'];
    if (base is! String || rawRates is! Map || unix is! num) {
      throw const FormatException('Неожиданный формат ответа');
    }
    return ExchangeRate(
      base: base.toUpperCase(),
      rates: _parseRates(rawRates),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        unix.toInt() * 1000,
        isUtc: true,
      ),
    );
  }

  // ---------- Резервный источник: currency-api через CDN jsDelivr ----------
  //
  // Пример ответа:
  // {"date":"2026-10-19","eur":{"rub":94.58,"usd":1.12,...}}

  factory ExchangeRate.fromCdnJson(Map<String, dynamic> json, String base) {
    final rawRates = json[base.toLowerCase()];
    final date = json['date'];
    if (rawRates is! Map || date is! String) {
      throw const FormatException('Неожиданный формат ответа');
    }
    final parsed = DateTime.tryParse(date);
    if (parsed == null) {
      throw const FormatException('Некорректная дата в ответе');
    }
    return ExchangeRate(
      base: base.toUpperCase(),
      rates: _parseRates(rawRates),
      updatedAt: DateTime.utc(parsed.year, parsed.month, parsed.day),
      hasTime: false,
    );
  }

  // ---------- JSON для кэша ----------

  Map<String, dynamic> toJson() {
    return {
      'base': base,
      'rates': rates,
      'updatedAt': updatedAt.toIso8601String(),
      'hasTime': hasTime,
    };
  }

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    final base = json['base'];
    final rawRates = json['rates'];
    final updated = json['updatedAt'];
    if (base is! String || rawRates is! Map || updated is! String) {
      throw const FormatException('Некорректные данные кэша');
    }
    final updatedAt = DateTime.tryParse(updated);
    if (updatedAt == null) {
      throw const FormatException('Некорректная дата в кэше');
    }
    return ExchangeRate(
      base: base,
      rates: _parseRates(rawRates),
      updatedAt: updatedAt.toUtc(),
      hasTime: json['hasTime'] != false,
    );
  }

  /// Оставляет только пары «код → число» и приводит коды к верхнему регистру.
  static Map<String, double> _parseRates(Map<dynamic, dynamic> raw) {
    final result = <String, double>{};
    raw.forEach((key, value) {
      if (key is String && value is num) {
        result[key.toUpperCase()] = value.toDouble();
      }
    });
    if (result.isEmpty) {
      throw const FormatException('В ответе нет курсов');
    }
    return result;
  }
}
