import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/chat_models.dart';

/// Extensions accepted for file attachments (mirrors the backend allowlist).
const kFileExtensions = ['pdf', 'txt', 'md', 'csv', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'jpg', 'jpeg', 'png', 'mp3', 'mp4'];

String _mimeFor(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    'txt' || 'md' || 'log' => 'text/plain',
    'csv' => 'text/csv',
    'zip' => 'application/zip',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'mp3' => 'audio/mpeg',
    'mp4' => 'video/mp4',
    'm4a' => 'audio/mp4',
    'webm' => 'audio/webm',
    _ => 'application/octet-stream',
  };
}

/// Pick + compress a photo (max 1600px, JPEG q80) ready to upload.
Future<PendingMedia?> pickImage(ImageSource source) async {
  final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  int? w, h;
  try {
    final img = await decodeImageFromList(bytes);
    w = img.width;
    h = img.height;
  } catch (_) {}
  final name = x.name.contains('.') ? x.name : '${x.name}.jpg';
  return PendingMedia(kind: 'IMAGE', bytes: bytes, fileName: name, mimeType: x.mimeType ?? _mimeFor(name), width: w, height: h);
}

/// Pick a document from the allowlist. Returns null when cancelled.
Future<PendingMedia?> pickDocument() async {
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: kFileExtensions);
  if (files.isEmpty) return null;
  final f = files.first;
  final size = await f.length();
  if (size != null && size > 20 * 1024 * 1024) throw const FileTooLarge();
  final bytes = await f.readAsBytes();
  return PendingMedia(kind: 'FILE', bytes: bytes, fileName: f.name, mimeType: _mimeFor(f.name));
}

class FileTooLarge implements Exception {
  const FileTooLarge();
}

// ---------------------------------------------------------------- bubbles

class MediaContent extends StatelessWidget {
  const MediaContent({super.key, required this.m, required this.mine});
  final ChatMessage m;
  final bool mine;

  @override
  Widget build(BuildContext context) => switch (m.type) {
        'IMAGE' => _ImageContent(m: m),
        'VOICE' => VoiceMessagePlayer(m: m, mine: mine),
        _ => _FileContent(m: m),
      };
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.m});
  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final a = m.attachment;
    final p = m.pending;
    final w = (a?.width ?? p?.width ?? 4).toDouble();
    final h = (a?.height ?? p?.height ?? 3).toDouble();
    final ratio = (w / h).clamp(0.6, 1.8);
    final Widget img = p != null
        ? Image.memory(p.bytes, fit: BoxFit.cover)
        : Image.network(
            a!.absoluteUrl,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, prog) => prog == null ? child : const ColoredBox(color: AppColors.surfaceHigh, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surfaceHigh, child: Center(child: Icon(Icons.broken_image_outlined))),
          );
    return GestureDetector(
      onTap: a == null ? null : () => _openViewer(context, a.absoluteUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 220, child: AspectRatio(aspectRatio: ratio, child: img)),
      ),
    );
  }

  void _openViewer(BuildContext context, String url) => showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(child: Center(child: Image.network(url))),
        ),
      );
}

class _FileContent extends StatelessWidget {
  const _FileContent({required this.m});
  final ChatMessage m;

  IconData _icon(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'zip' => Icons.folder_zip_rounded,
      'doc' || 'docx' || 'txt' || 'md' => Icons.description_rounded,
      'xls' || 'xlsx' || 'csv' => Icons.table_chart_rounded,
      'ppt' || 'pptx' => Icons.slideshow_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = m.attachment;
    final name = a?.fileName ?? m.pending?.fileName ?? '';
    final size = a?.sizeBytes ?? m.pending?.bytes.length ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: a == null ? null : () => launchUrl(Uri.parse(a.downloadUrl), mode: LaunchMode.externalApplication),
      child: SizedBox(
        width: 230,
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(_icon(name), color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                a == null ? l.uploading : '${formatBytes(size)} · ${l.download}',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Play/pause + scrub-free progress over pseudo-waveform bars.
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({super.key, required this.m, required this.mine});
  final ChatMessage m;
  final bool mine;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  AudioPlayer? _player;
  bool _loading = false;
  final List<StreamSubscription> _subs = [];
  Duration _pos = Duration.zero;
  bool _playing = false;

  Duration get _total => Duration(milliseconds: widget.m.attachment?.durationMs ?? widget.m.pending?.durationMs ?? 0);

  Future<void> _toggle() async {
    final a = widget.m.attachment;
    if (a == null) return;
    var p = _player;
    if (p == null) {
      setState(() => _loading = true);
      p = _player = AudioPlayer();
      _subs.add(p.positionStream.listen((d) => mounted ? setState(() => _pos = d) : null));
      _subs.add(p.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          p!.pause();
          p.seek(Duration.zero);
        }
        setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
      }));
      try {
        await p.setUrl(a.absoluteUrl);
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    _playing ? await p.pause() : unawaited(p.play());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _total.inMilliseconds == 0 ? const Duration(seconds: 1) : _total;
    final progress = (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final seed = widget.m.id.hashCode;
    final shown = _playing || _pos > Duration.zero ? _pos : _total;
    return SizedBox(
      width: 220,
      child: Row(children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggle,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: widget.mine ? 0.25 : 0.12)),
            child: _loading
                ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 28,
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              for (var i = 0; i < 26; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: 6 + 20 * (0.35 + 0.65 * ((math.sin(seed + i * 1.7) + 1) / 2)) * (i % 5 == 0 ? 0.6 : 1),
                    decoration: BoxDecoration(
                      color: (i / 26) <= progress && progress > 0 ? Colors.white : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text(formatDuration(shown), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
      ]),
    );
  }
}

// ---------------------------------------------------------------- recorder

/// Hold-to-record mic button. Slide left to cancel. Calls [onRecorded] on release.
class HoldToRecordButton extends StatefulWidget {
  const HoldToRecordButton({super.key, required this.onRecorded, required this.onRecordingChanged, this.onError});
  final ValueChanged<PendingMedia> onRecorded;
  final void Function(bool recording, Duration elapsed, bool cancelling) onRecordingChanged;
  final ValueChanged<String>? onError;

  @override
  State<HoldToRecordButton> createState() => _HoldToRecordButtonState();
}

class _HoldToRecordButtonState extends State<HoldToRecordButton> {
  final _rec = AudioRecorder();
  DateTime? _startedAt;
  Timer? _tick;
  bool _cancel = false;
  bool _recording = false;
  static const _minDuration = Duration(milliseconds: 800);
  static const _maxDuration = Duration(minutes: 5);

  Duration get _elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  Future<void> _start() async {
    final l = context.l10n;
    if (!await _rec.hasPermission()) {
      widget.onError?.call(l.micPermission);
      return;
    }
    final config = RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc, numChannels: 1, bitRate: 64000);
    final path = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(config, path: path);
    _startedAt = DateTime.now();
    _cancel = false;
    setState(() => _recording = true);
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      widget.onRecordingChanged(true, _elapsed, _cancel);
      if (_elapsed >= _maxDuration) _stop();
    });
    widget.onRecordingChanged(true, Duration.zero, false);
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _tick?.cancel();
    final elapsed = _elapsed;
    final cancelled = _cancel;
    _recording = false;
    final path = await _rec.stop();
    if (mounted) setState(() {});
    widget.onRecordingChanged(false, Duration.zero, false);
    if (cancelled || path == null) return;
    if (elapsed < _minDuration) {
      if (mounted) widget.onError?.call(context.l10n.recordTooShort);
      return;
    }
    final bytes = await XFile(path).readAsBytes();
    widget.onRecorded(PendingMedia(
      kind: 'VOICE',
      bytes: bytes,
      fileName: kIsWeb ? 'voice.webm' : 'voice.m4a',
      mimeType: kIsWeb ? 'audio/webm' : 'audio/mp4',
      durationMs: elapsed.inMilliseconds,
    ));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Tooltip(
      message: l.holdToRecord,
      child: GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressMoveUpdate: (d) {
          final c = d.offsetFromOrigin.dx < -80;
          if (c != _cancel) setState(() => _cancel = c);
        },
        onLongPressEnd: (_) => _stop(),
        onTap: () => widget.onError?.call(l.holdToRecord),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _recording ? 62 : 50,
          height: _recording ? 62 : 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _recording ? null : AppColors.coolGradient,
            color: _recording ? (_cancel ? AppColors.textFaint : AppColors.danger) : null,
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.white),
        ),
      ),
    );
  }
}
