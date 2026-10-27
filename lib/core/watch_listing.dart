/// Dati certi di un orologio, inseriti dall'utente.
/// Logica pura Dart (nessun plugin): testabile in CI.
class WatchListing {
  final String brand;
  final String model;
  final String reference;
  final String year;
  final String condition;
  final bool hasBox;
  final bool hasPapers;
  final String price;
  final String notes;

  const WatchListing({
    this.brand = '',
    this.model = '',
    this.reference = '',
    this.year = '',
    this.condition = '',
    this.hasBox = false,
    this.hasPapers = false,
    this.price = '',
    this.notes = '',
  });

  bool get isEmpty =>
      brand.trim().isEmpty &&
      model.trim().isEmpty &&
      reference.trim().isEmpty;

  String get corredo {
    if (hasBox && hasPapers) return 'Full set (scatola e garanzia/documenti)';
    if (hasBox) return 'Solo scatola';
    if (hasPapers) return 'Solo garanzia/documenti';
    return 'Solo orologio';
  }

  /// Righe "campo: valore" solo per i campi compilati.
  List<String> factLines() {
    final lines = <String>[];
    void add(String label, String value) {
      if (value.trim().isNotEmpty) lines.add('- $label: ${value.trim()}');
    }

    add('Marca', brand);
    add('Modello', model);
    add('Referenza', reference);
    add('Anno', year);
    add('Condizioni', condition);
    lines.add('- Corredo: $corredo');
    add('Prezzo', price);
    add('Note del venditore', notes);
    return lines;
  }
}

/// Impostazioni fisse della pagina, aggiunte a ogni richiesta.
class ShopProfile {
  final String pageName;
  final String city;
  final String footer;

  const ShopProfile({this.pageName = '', this.city = '', this.footer = ''});

  List<String> lines() {
    final out = <String>[];
    if (pageName.trim().isNotEmpty) out.add('- Nome pagina: ${pageName.trim()}');
    if (city.trim().isNotEmpty) out.add('- Città: ${city.trim()}');
    if (footer.trim().isNotEmpty) {
      out.add('- Testo fisso da mettere in fondo alla didascalia: ${footer.trim()}');
    }
    return out;
  }
}

const List<String> kConditions = [
  'Nuovo, mai indossato',
  'Come nuovo',
  'Ottime condizioni',
  'Buone condizioni',
  'Usato con segni evidenti',
];
