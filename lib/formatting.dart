/// Форматирование чисел и дат для показа пользователю.

/// 9387.6993 -> «9 387.70» (пробел между тысячами неразрывный).
/// Очень маленькие суммы показываем с шестью знаками.
String formatMoney(double value) {
  final small = value != 0 && value.abs() < 0.01;
  return _groupThousands(value.toStringAsFixed(small ? 6 : 2));
}

/// Курс: чем он меньше, тем больше знаков после точки.
String formatRate(double rate) {
  final int digits;
  if (rate >= 100) {
    digits = 2;
  } else if (rate >= 1) {
    digits = 4;
  } else {
    digits = 6;
  }
  return _groupThousands(rate.toStringAsFixed(digits));
}

/// Дата обновления курса: «19.10.2026 05:02» (по времени устройства)
/// или только «19.10.2026», если источник не дал время.
String formatUpdated(DateTime utc, {required bool withTime}) {
  if (!withTime) {
    return '${_two(utc.day)}.${_two(utc.month)}.${utc.year}';
  }
  final local = utc.toLocal();
  return '${_two(local.day)}.${_two(local.month)}.${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _groupThousands(String fixed) {
  final negative = fixed.startsWith('-');
  final body = negative ? fixed.substring(1) : fixed;
  final parts = body.split('.');
  final integer = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ' ',
  );
  // Десятичная запятая, как в российском формате: 10 800,00
  final result = parts.length > 1 ? '$integer,${parts[1]}' : integer;
  return negative ? '-$result' : result;
}