import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../config/env.dart';
import '../config/server_config.dart';
import '../l10n_ext.dart';
import '../locale_controller.dart';

/// Hidden tester entry point: long-press the wrapped widget (the logo) to change the API server.
class ServerAddressTrigger extends ConsumerWidget {
  const ServerAddressTrigger({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        key: const Key('server-address-trigger'),
        behavior: HitTestBehavior.opaque,
        onLongPress: () => showServerAddressDialog(context, ref),
        child: child,
      );
}

Future<void> showServerAddressDialog(BuildContext context, WidgetRef ref) async {
  final changed = await showDialog<bool>(context: context, builder: (_) => const ServerAddressDialog());
  if (changed == true && ref.read(authControllerProvider) is AuthOffline) {
    await ref.read(authControllerProvider.notifier).restore();
  }
}

/// Probes `GET <url>/health` with a short timeout.
typedef ServerProbe = Future<bool> Function(String url);

Future<bool> defaultServerProbe(String url) async {
  try {
    final r = await Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    )).get<dynamic>('$url/health');
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

class ServerAddressDialog extends ConsumerStatefulWidget {
  const ServerAddressDialog({super.key, this.probe = defaultServerProbe});
  final ServerProbe probe;
  @override
  ConsumerState<ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends ConsumerState<ServerAddressDialog> {
  late final _ctrl = TextEditingController(text: ServerConfig.current);
  String? _error;
  String? _status;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final l = context.l10n;
    final url = ServerConfig.normalize(_ctrl.text);
    if (url == null) return setState(() => _error = l.serverInvalid);
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    final ok = await widget.probe(url);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = ok ? l.serverReachable : l.serverUnreachable;
    });
  }

  Future<void> _save({bool reset = false}) async {
    final prefs = ref.read(sharedPrefsProvider);
    try {
      await ServerConfig.save(prefs, reset ? null : _ctrl.text);
      if (mounted) Navigator.pop(context, true);
    } on FormatException {
      setState(() => _error = context.l10n.serverInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.serverAddress),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          key: const Key('server-url'),
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(hintText: 'http://192.168.1.10:3000', errorText: _error),
          onChanged: (_) => setState(() {
            _error = null;
            _status = null;
          }),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Text('${l.serverDefault}: ${Env.apiBaseUrl}', style: Theme.of(context).textTheme.bodySmall),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!)),
      ]),
      actions: [
        TextButton(onPressed: () => _save(reset: true), child: Text(l.serverReset)),
        TextButton(onPressed: _busy ? null : _test, child: Text(l.serverTest)),
        FilledButton(key: const Key('server-save'), onPressed: () => _save(), child: Text(l.save)),
      ],
    );
  }
}
