import 'package:shared_preferences/shared_preferences.dart';

import '../core/watch_listing.dart';

class AppSettings {
  final String apiKey;
  final String model;
  final ShopProfile shop;

  const AppSettings({
    this.apiKey = '',
    this.model = kDefaultModel,
    this.shop = const ShopProfile(),
  });

  bool get hasKey => apiKey.trim().isNotEmpty;
}

const String kDefaultModel = 'gemini-3.8-flash';

/// Modelli Gemini del piano gratuito: (id API, etichetta).
/// Se Google ne ritira uno, l'app mostra un errore e si sceglie l'altro.
const List<(String, String)> kModels = [
  ('gemini-3.8-flash', 'Gemini 3.8 Flash (consigliato)'),
  ('gemini-3.6-flash', 'Gemini 3.6 Flash'),
  ('gemini-3.5-flash-lite', 'Gemini 3.5 Flash-Lite: più limiti al giorno, più semplice'),
];

class SettingsStore {
  final _prefs = SharedPreferencesAsync();

  Future<AppSettings> load() async {
    final model = await _prefs.getString('model') ?? kDefaultModel;
    return AppSettings(
      apiKey: await _prefs.getString('apiKey') ?? '',
      model: kModels.any((m) => m.$1 == model) ? model : kDefaultModel,
      shop: ShopProfile(
        pageName: await _prefs.getString('pageName') ?? '',
        city: await _prefs.getString('city') ?? '',
        footer: await _prefs.getString('footer') ?? '',
      ),
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setString('apiKey', s.apiKey.trim());
    await _prefs.setString('model', s.model);
    await _prefs.setString('pageName', s.shop.pageName);
    await _prefs.setString('city', s.shop.city);
    await _prefs.setString('footer', s.shop.footer);
  }
}
