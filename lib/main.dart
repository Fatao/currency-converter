import 'package:flutter/material.dart';

import 'api_client.dart';
import 'converter_state.dart';
import 'currencies.dart';
import 'currency_repository.dart';
import 'formatting.dart';
import 'rate_cache.dart';

void main() {
  final repository = CurrencyRepository(
    api: ApiClient(),
    cache: SharedPrefsRateCache(),
  );
  runApp(CurrencyConverterApp(repository: repository));
}

class CurrencyConverterApp extends StatelessWidget {
  const CurrencyConverterApp({super.key, required this.repository});

  final RatesRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Конвертер валют',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F6FEB),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: ConverterPage(repository: repository),
    );
  }
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key, required this.repository});

  final RatesRepository repository;

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  late final ConverterState _state;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _state = ConverterState(widget.repository);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _state.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _state.convert();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Конвертер валют',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: _state,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FieldLabel('Сумма'),
                      TextField(
                        key: const ValueKey('amount_field'),
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: _state.setAmountText,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _fieldDecoration(
                          context,
                          errorText: _state.inputError,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Из'),
                      _CurrencyDropdown(
                        fieldKey: const ValueKey('from_dropdown'),
                        value: _state.from,
                        onChanged: _state.setFrom,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          key: const ValueKey('swap_button'),
                          tooltip: 'Поменять местами',
                          icon: const Icon(Icons.swap_vert),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: _state.isLoading ? null : _state.swap,
                        ),
                      ),
                      const _FieldLabel('В'),
                      _CurrencyDropdown(
                        fieldKey: const ValueKey('to_dropdown'),
                        value: _state.to,
                        onChanged: _state.setTo,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const ValueKey('convert_button'),
                        onPressed: _state.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Конвертировать',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ResultArea(state: _state, onRetry: _submit),
                      const SizedBox(height: 24),
                      Text(
                        'Rates By Exchange Rate API (exchangerate-api.com)',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, {String? errorText}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );
  return InputDecoration(
    errorText: errorText,
    filled: true,
    fillColor: Colors.white,
    border: border,
    enabledBorder: border,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Значок валюты: круг с символом (флаги потребовали бы отдельных картинок).
class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final symbol = currencySymbols[code] ?? code.substring(0, 1);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _CurrencyBadge(code),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                code,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                supportedCurrencies[code] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.fieldKey,
    required this.value,
    required this.onChanged,
  });

  final Key fieldKey;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final codes = supportedCurrencies.keys.toList();
    return DropdownButtonFormField<String>(
      key: fieldKey,
      value: value,
      isExpanded: true,
      itemHeight: 64,
      borderRadius: BorderRadius.circular(12),
      decoration: _fieldDecoration(context).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      selectedItemBuilder: (context) => [
        for (final code in codes) _CurrencyTile(code),
      ],
      items: [
        for (final code in codes)
          DropdownMenuItem(value: code, child: _CurrencyTile(code)),
      ],
      onChanged: (code) {
        if (code != null) onChanged(code);
      },
    );
  }
}

class _ResultArea extends StatelessWidget {
  const _ResultArea({required this.state, required this.onRetry});

  final ConverterState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ConvertStatus.idle:
        return const SizedBox.shrink();
      case ConvertStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(key: ValueKey('loading')),
          ),
        );
      case ConvertStatus.error:
        return _ErrorCard(
          message: state.errorMessage ?? 'Ошибка',
          onRetry: onRetry,
        );
      case ConvertStatus.success:
        return _ResultCard(state: state);
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.state});

  final ConverterState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updated = state.updatedAt;
    return Card(
      key: const ValueKey('result_card'),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Результат', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${formatMoney(state.result!)} ${state.resultTo}',
                key: const ValueKey('result_text'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatMoney(state.convertedAmount!)} ${state.resultFrom} = '
              '${formatMoney(state.result!)} ${state.resultTo}',
              key: const ValueKey('equation_text'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Курс: 1 ${state.resultFrom} = '
              '${formatRate(state.rate!)} ${state.resultTo}',
              key: const ValueKey('rate_text'),
            ),
            if (updated != null)
              Text(
                'Курс актуален на ${formatUpdated(updated, withTime: state.hasTime)}',
                key: const ValueKey('updated_text'),
                style: theme.textTheme.bodySmall,
              ),
            if (state.fromCache)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Нет связи с сервером — показан последний сохранённый курс.',
                  key: const ValueKey('cache_note'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('error_card'),
      elevation: 0,
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    key: const ValueKey('error_text'),
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('retry_button'),
                onPressed: onRetry,
                child: const Text('Повторить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}