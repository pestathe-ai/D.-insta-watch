import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../core/post_result.dart';
import '../services/ai_client.dart';

class ResultScreen extends StatefulWidget {
  final PostResult initial;
  final List<XFile> photos;
  final Future<PostResult> Function() regenerate;

  const ResultScreen({
    super.key,
    required this.initial,
    required this.photos,
    required this.regenerate,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late PostResult _result;
  late final TextEditingController _caption;
  late final TextEditingController _tags;
  late final TextEditingController _dm;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController();
    _tags = TextEditingController();
    _dm = TextEditingController();
    _apply(widget.initial);
  }

  void _apply(PostResult r) {
    _result = r;
    _caption.text = r.caption;
    _tags.text = r.hashtags.join(' ');
    _dm.text = r.dmReply;
  }

  @override
  void dispose() {
    _caption.dispose();
    _tags.dispose();
    _dm.dispose();
    super.dispose();
  }

  String get _fullCaption {
    final tags = normalizeHashtags([_tags.text]).join(' ');
    final text = _caption.text.trim();
    return tags.isEmpty ? text : '$text\n\n$tags';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _snack('$what copiata.');
  }

  Future<void> _share() async {
    final caption = _fullCaption;
    // Instagram ignora il testo condiviso: la didascalia va incollata a mano.
    await Clipboard.setData(ClipboardData(text: caption));
    if (!mounted) return;
    _snack('Didascalia copiata: incollala su Instagram.');
    try {
      await SharePlus.instance.share(
        widget.photos.isEmpty
            ? ShareParams(text: caption)
            : ShareParams(files: widget.photos, text: caption),
      );
    } catch (e) {
      if (mounted) _snack('Condivisione non riuscita: $e');
    }
  }

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    try {
      final r = await widget.regenerate();
      if (!mounted) return;
      setState(() => _apply(r));
      _snack('Nuova versione pronta.');
    } on AiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Il tuo post'),
        actions: [
          IconButton(
            tooltip: 'Rigenera',
            onPressed: _busy ? null : _regenerate,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (r.warnings.isNotEmpty)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Text('Da controllare',
                            style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final w in r.warnings)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $w',
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer)),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          _Section(
            title: 'Didascalia',
            onCopy: () => _copy(_fullCaption, 'Didascalia con hashtag'),
            child: TextField(
              controller: _caption,
              minLines: 6,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          _Section(
            title: 'Hashtag (max 5)',
            onCopy: () => _copy(_tags.text.trim(), 'Lista hashtag'),
            child: TextField(controller: _tags, maxLines: null),
          ),
          if (r.stories.isNotEmpty)
            _Section(
              title: 'Storie',
              child: Column(
                children: [
                  for (var i = 0; i < r.stories.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${i + 1}'),
                      ),
                      title: Text(r.stories[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () =>
                            _copy(r.stories[i], 'Slide ${i + 1}'),
                      ),
                    ),
                ],
              ),
            ),
          if (r.dmReply.isNotEmpty)
            _Section(
              title: 'Risposta pronta per i DM',
              onCopy: () => _copy(_dm.text.trim(), 'Risposta DM'),
              child: TextField(
                controller: _dm,
                minLines: 3,
                maxLines: null,
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.sizeOf(context).width - 32,
        height: 56,
        child: FilledButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.ios_share),
          label: const Text('Copia e condividi su Instagram'),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onCopy;
  const _Section({required this.title, required this.child, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (onCopy != null)
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copia'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
