import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exchange_rate.dart';

/// Типы сетевых ошибок, которые умеет различать приложение.
enum ApiErrorType { noConnection, timeout, rateLimited, server, badResponse }

/// Ошибка получения курсов. Сообщение можно показывать пользователю как есть.
class ApiException implements Exception {
  const ApiException(this.type, this.message);

  final ApiErrorType type;
  final String message;

  @override
  String toString() => 'ApiException($type): $message';
}

/// Единственное место в приложении, которое работает с HTTP.
/// Ничего не знает ни о виджетах, ни о состоянии интерфейса.
class ApiClient {
  ApiClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Сколько ждать ответа сервера, прежде чем сдаться.
  final Duration timeout;

  /// Основной источник (бесплатный, без ключа, обновляется раз в сутки).
  Future<ExchangeRate> fetchPrimary(String base) async {
    final code = base.toUpperCase();
    final json = await _getJson(Uri.parse('https://open.er-api.com/v6/latest/$code'));
    return _parse(() => ExchangeRate.fromErApiJson(json));
  }

  /// Резервный источник: тот же тип данных через CDN.
  Future<ExchangeRate> fetchBackup(String base) async {
    final code = base.toLowerCase();
    final uri = Uri.parse(
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/$code.json',
    );
    final json = await _getJson(uri);
    return _parse(() => ExchangeRate.fromCdnJson(json, base));
  }

  /// Выполняет GET и превращает любые сбои в понятный ApiException.
  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        ApiErrorType.timeout,
        'Сервер долго не отвечает. Повторите попытку позже.',
      );
    } on http.ClientException {
      // Нет сети, DNS не нашёл сервер, соединение оборвано.
      throw const ApiException(
        ApiErrorType.noConnection,
        'Нет подключения к интернету. Проверьте сеть и повторите попытку.',
      );
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _get(uri);

    if (response.statusCode == 429) {
      throw const ApiException(
        ApiErrorType.rateLimited,
        'Слишком много запросов к серверу курсов. Подождите немного.',
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        ApiErrorType.server,
        'Ошибка сервера (код ${response.statusCode}). Повторите попытку позже.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      // Пришёл не JSON (например, HTML-страница) — обработаем ниже.
    }
    throw const ApiException(
      ApiErrorType.badResponse,
      'Сервер вернул некорректный ответ.',
    );
  }

  /// Превращает ошибку разбора JSON в модель в понятный ApiException.
  ExchangeRate _parse(ExchangeRate Function() parser) {
    try {
      return parser();
    } on FormatException {
      throw const ApiException(
        ApiErrorType.badResponse,
        'Сервер вернул некорректный ответ.',
      );
    }
  }
}
