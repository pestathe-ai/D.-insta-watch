import 'package:flutter/material.dart';

import '../core/watch_listing.dart';
import '../services/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings initial;
  const SettingsScreen({super.key, required this.initial});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _key;
  late final TextEditingController _page;
  late final TextEditingController _city;
  late final TextEditingController _footer;
  late String _model;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _key = TextEditingController(text: s.apiKey);
    _page = TextEditingController(text: s.shop.pageName);
    _city = TextEditingController(text: s.shop.city);
    _footer = TextEditingController(text: s.shop.footer);
    _model = s.model;
  }

  @override
  void dispose() {
    _key.dispose();
    _page.dispose();
    _city.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppSettings(
      apiKey: _key.text.trim(),
      model: _model,
      shop: ShopProfile(
        pageName: _page.text.trim(),
        city: _city.text.trim(),
        footer: _footer.text.trim(),
      ),
    );
    await SettingsStore().save(s);
    if (!mounted) return;
    Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Collegamento a Gemini (gratis)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Chiave API Gemini (AIza...)',
              helperText: 'Gratis su aistudio.google.com → Get API key. Resta solo su questo telefono.',
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _model,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Modello'),
            items: [
              for (final m in kModels)
                DropdownMenuItem(
                  value: m.$1,
                  child: Text(m.$2, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _model = v ?? kDefaultModel),
          ),
          const SizedBox(height: 28),
          Text('La tua pagina', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Usati in ogni post, così non devi riscriverli.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _page,
            decoration: const InputDecoration(labelText: 'Nome della pagina'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Città (facoltativa)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footer,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Testo fisso in fondo ai post',
              hintText: 'Es. Spedizione assicurata in tutta Italia. Possibile visione su appuntamento.',
              hintMaxLines: 3,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
