import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';

Future<bool> _pinDialog(BuildContext context,
    {required String title, required bool create}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(title: title, create: create),
  );
  return r ?? false;
}

Future<bool> createPin(BuildContext context) =>
    _pinDialog(context, title: 'PIN belirle', create: true);

Future<bool> verifyPin(BuildContext context) =>
    _pinDialog(context, title: 'PIN gir', create: false);

/// Kilitli icerik icin: PIN yoksa olusturtur, varsa sorar. Basariliysa
/// 15 dakika boyunca kilit acik kalir.
Future<bool> requestUnlock(BuildContext context) async {
  if (Store.isUnlocked) return true;
  final ok = Store.hasPin ? await verifyPin(context) : await createPin(context);
  if (ok) Store.unlock();
  return ok;
}

class _PinDialog extends StatefulWidget {
  final String title;
  final bool create;
  const _PinDialog({required this.title, required this.create});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _err;

  Future<void> _ok() async {
    final pin = _a.text.trim();
    if (pin.length < 4) {
      setState(() => _err = 'En az 4 haneli olmalı');
      return;
    }
    if (widget.create) {
      if (pin != _b.text.trim()) {
        setState(() => _err = 'PIN\'ler eşleşmiyor');
        return;
      }
      await Store.setPin(pin);
      if (mounted) Navigator.pop(context, true);
    } else {
      if (Store.checkPin(pin)) {
        Navigator.pop(context, true);
      } else {
        setState(() => _err = 'PIN hatalı');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.lock_outline),
        const SizedBox(width: 10),
        Text(widget.title),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _a,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: widget.create ? 'Yeni PIN (en az 4 hane)' : 'PIN',
              counterText: '',
            ),
            onSubmitted: widget.create ? null : (_) => _ok(),
          ),
          if (widget.create) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _b,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN tekrar',
                counterText: '',
              ),
              onSubmitted: (_) => _ok(),
            ),
          ],
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Tamam')),
      ],
    );
  }
}
