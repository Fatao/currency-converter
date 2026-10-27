import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'exchange_rate.dart';

/// Хранилище последнего удачно полученного курса (дополнительное задание).
abstract class RateCache {
  Future<ExchangeRate?> load(String base);
  Future<void> save(ExchangeRate rate);
}

/// Реальный кэш: сохраняет курс на устройстве (shared_preferences).
class SharedPrefsRateCache implements RateCache {
  static String _key(String base) => 'rates_${base.toUpperCase()}';

  @override
  Future<ExchangeRate?> load(String base) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_key(base));
      if (text == null) return null;
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return ExchangeRate.fromJson(decoded);
      }
    } catch (_) {
      // Повреждённый или недоступный кэш не должен ломать приложение.
    }
    return null;
  }

  @override
  Future<void> save(ExchangeRate rate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(rate.base), jsonEncode(rate.toJson()));
    } catch (_) {
      // Не удалось сохранить — не страшно, просто не будет кэша.
    }
  }
}

/// Кэш в памяти — для тестов.
class MemoryRateCache implements RateCache {
  final Map<String, ExchangeRate> _items = {};

  @override
  Future<ExchangeRate?> load(String base) async => _items[base.toUpperCase()];

  @override
  Future<void> save(ExchangeRate rate) async {
    _items[rate.base.toUpperCase()] = rate;
  }
}
