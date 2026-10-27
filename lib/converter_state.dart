import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'currency_repository.dart';
import 'exchange_rate.dart';

enum ConvertStatus { idle, loading, success, error }

/// Состояние экрана конвертера. Не знает про виджеты и HTTP:
/// получает курсы через RatesRepository.
class ConverterState extends ChangeNotifier {
  ConverterState(this._repository);

  final RatesRepository _repository;

  static const double maxAmount = 1e12;

  String from = 'EUR';
  String to = 'RUB';
  String amountText = '';

  ConvertStatus status = ConvertStatus.idle;

  /// Ошибка ввода (пусто, не число, отрицательное) — показывается под полем.
  String? inputError;

  /// Ошибка сети/сервера — показывается в карточке ошибки.
  String? errorMessage;

  // Данные последнего успешного расчёта.
  double? result;
  double? rate;
  double? convertedAmount;
  String? resultFrom;
  String? resultTo;
  DateTime? updatedAt;
  bool hasTime = true;
  bool fromCache = false;

  int _requestId = 0;
  bool _disposed = false;

  bool get isLoading => status == ConvertStatus.loading;

  void setAmountText(String value) {
    amountText = value;
    if (inputError != null) {
      inputError = null;
      notifyListeners();
    }
  }

  void setFrom(String code) {
    if (code == from) return;
    from = code;
    _invalidateResult();
  }

  void setTo(String code) {
    if (code == to) return;
    to = code;
    _invalidateResult();
  }

  /// Меняет валюты местами. Если результат уже был показан — пересчитывает.
  Future<void> swap() async {
    final wasSuccess = status == ConvertStatus.success;
    final tmp = from;
    from = to;
    to = tmp;
    if (wasSuccess) {
      await convert();
    } else {
      _invalidateResult();
    }
  }

  /// Проверяет ввод. Возвращает число или null (и выставляет inputError).
  double? _validate() {
    final text = amountText.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      inputError = 'Введите сумму';
      return null;
    }
    final value = double.tryParse(text);
    if (value == null || value.isNaN || value.isInfinite) {
      inputError = 'Введите число, например 100 или 12.5';
      return null;
    }
    if (value < 0) {
      inputError = 'Сумма не может быть отрицательной';
      return null;
    }
    if (value > maxAmount) {
      inputError = 'Слишком большая сумма';
      return null;
    }
    return value;
  }

  Future<void> convert() async {
    final amount = _validate();
    if (amount == null) {
      status = ConvertStatus.idle;
      errorMessage = null;
      result = null;
      notifyListeners();
      return;
    }

    inputError = null;
    errorMessage = null;
    status = ConvertStatus.loading;
    final id = ++_requestId;
    final requestFrom = from;
    final requestTo = to;
    notifyListeners();

    try {
      final ExchangeRate rates = await _repository.getRates(requestFrom);
      if (_isStale(id)) return;

      final r = rates.rateTo(requestTo);
      if (r == null) {
        throw const ApiException(
          ApiErrorType.badResponse,
          'Для выбранной валюты нет курса.',
        );
      }
      rate = r;
      convertedAmount = amount;
      result = amount * r;
      resultFrom = requestFrom;
      resultTo = requestTo;
      updatedAt = rates.updatedAt;
      hasTime = rates.hasTime;
      fromCache = rates.fromCache;
      status = ConvertStatus.success;
    } on ApiException catch (e) {
      if (_isStale(id)) return;
      _fail(e.message);
    } catch (_) {
      if (_isStale(id)) return;
      _fail('Произошла непредвиденная ошибка.');
    }
    notifyListeners();
  }

  void _fail(String message) {
    errorMessage = message;
    result = null;
    status = ConvertStatus.error;
  }

  /// Ответ устарел, если пользователь успел запустить новый запрос
  /// или экран уже закрыт.
  bool _isStale(int id) => _disposed || id != _requestId;

  /// Сменили валюту — старый результат больше не соответствует выбору.
  void _invalidateResult() {
    _requestId++; // отменяем влияние запроса, который ещё в пути
    status = ConvertStatus.idle;
    result = null;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
