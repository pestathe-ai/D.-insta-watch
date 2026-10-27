import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/post_result.dart';
import '../core/prompt_builder.dart';
import '../core/watch_listing.dart';
import '../services/ai_client.dart';
import '../services/settings_store.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

const int kMaxPhotos = 4;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _client = AiClient();

  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _ref = TextEditingController();
  final _year = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  String? _condition;
  bool _box = false;
  bool _papers = false;

  final List<XFile> _photos = [];
  AppSettings _settings = const AppSettings();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await SettingsStore().load();
    if (!mounted) return;
    setState(() => _settings = s);
  }

  @override
  void dispose() {
    for (final c in [_brand, _model, _ref, _year, _price, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(builder: (_) => SettingsScreen(initial: _settings)),
    );
    if (updated != null && mounted) setState(() => _settings = updated);
  }

  Future<void> _pickGallery() async {
    final free = kMaxPhotos - _photos.length;
    if (free <= 0) {
      _snack('Massimo $kMaxPhotos foto.');
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1568,
        maxHeight: 1568,
        imageQuality: 85,
        limit: free > 1 ? free : null,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() => _photos.addAll(picked.take(free)));
      if (picked.length > free) _snack('Tenute le prime $free foto.');
    } catch (e) {
      _snack('Impossibile aprire la galleria: $e');
    }
  }

  Future<void> _pickCamera() async {
    if (_photos.length >= kMaxPhotos) {
      _snack('Massimo $kMaxPhotos foto.');
      return;
    }
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1568,
        maxHeight: 1568,
        imageQuality: 85,
      );
      if (shot == null || !mounted) return;
      setState(() => _photos.add(shot));
    } catch (e) {
      _snack('Impossibile aprire la fotocamera: $e');
    }
  }

  WatchListing _listing() => WatchListing(
        brand: _brand.text,
        model: _model.text,
        reference: _ref.text,
        year: _year.text,
        condition: _condition ?? '',
        hasBox: _box,
        hasPapers: _papers,
        price: _price.text,
        notes: _notes.text,
      );

  Future<List<ImagePart>> _encodePhotos() async {
    final parts = <ImagePart>[];
    var skipped = 0;
    for (final p in _photos) {
      final bytes = await p.readAsBytes();
      final type = detectMediaType(bytes);
      if (type == null) {
        skipped++;
        continue;
      }
      parts.add(ImagePart(type, base64Encode(bytes)));
    }
    if (skipped > 0) {
      _snack('$skipped foto in formato non supportato: saltate.');
    }
    return parts;
  }

  Future<PostResult> _callAi() async {
    final listing = _listing();
    final images = await _encodePhotos();
    final prompt = buildUserPrompt(
      listing,
      _settings.shop,
      photoCount: images.length,
    );
    return _client.generate(
      apiKey: _settings.apiKey,
      model: _settings.model,
      userPrompt: prompt,
      images: images,
    );
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    if (!_settings.hasKey) {
      _snack('Prima inserisci la chiave API nelle Impostazioni.');
      await _openSettings();
      return;
    }
    if (_listing().isEmpty && _photos.isEmpty) {
      _snack('Aggiungi almeno una foto o marca e modello.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await _callAi();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            initial: result,
            photos: List.of(_photos),
            regenerate: _callAi,
          ),
        ),
      );
    } on AiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Errore: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    setState(() {
      for (final c in [_brand, _model, _ref, _year, _price, _notes]) {
        c.clear();
      }
      _condition = null;
      _box = false;
      _papers = false;
      _photos.clear();
    });
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard, String? hint}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('D. Insta Watch'),
        actions: [
          IconButton(
            tooltip: 'Svuota',
            icon: const Icon(Icons.restart_alt),
            onPressed: _loading ? null : _clear,
          ),
          IconButton(
            tooltip: 'Impostazioni',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _loading ? null : _openSettings,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (!_settings.hasKey)
              Card(
                color: theme.colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('Inserisci la chiave gratuita di Gemini'),
                  subtitle: const Text('Tocca qui per aprire le Impostazioni.'),
                  onTap: _openSettings,
                ),
              ),
            const SizedBox(height: 8),
            Text('Foto (${_photos.length}/$kMaxPhotos)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_photos[i].path),
                              width: 104,
                              height: 104,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              iconSize: 16,
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => _photos.removeAt(i)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photos.length < kMaxPhotos) ...[
                    _AddPhotoTile(
                      icon: Icons.photo_library_outlined,
                      label: 'Galleria',
                      onTap: _pickGallery,
                    ),
                    const SizedBox(width: 8),
                    _AddPhotoTile(
                      icon: Icons.photo_camera_outlined,
                      label: 'Scatta',
                      onTap: _pickCamera,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Dati certi', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'L'IA usa solo questi per referenza, anno e corredo: non li inventa.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _field(_brand, 'Marca', hint: 'Es. Omega'),
            const SizedBox(height: 12),
            _field(_model, 'Modello', hint: 'Es. Seamaster Diver 300M'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_ref, 'Referenza')),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_year, 'Anno', keyboard: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Condizioni'),
              items: [
                for (final c in kConditions)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _condition = v),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _box,
              title: const Text('Scatola'),
              onChanged: (v) => setState(() => _box = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _papers,
              title: const Text('Garanzia / documenti'),
              onChanged: (v) => setState(() => _papers = v ?? false),
            ),
            _field(_price, 'Prezzo (vuoto = "Prezzo in DM")',
                keyboard: TextInputType.text, hint: 'Es. 4.900 €'),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (facoltative)',
                hintText: 'Es. revisionato a marzo, bracciale accorciato, '
                    'graffio sulla fibbia',
                hintMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.sizeOf(context).width - 32,
        height: 56,
        child: FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_loading ? 'Sto scrivendo il post…' : 'Crea il post'),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddPhotoTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}
