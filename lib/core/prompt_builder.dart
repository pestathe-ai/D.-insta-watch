import 'watch_listing.dart';

const String kSystemPrompt = '''
Sei il social media manager di una pagina Instagram italiana che VENDE orologi.
Scrivi in italiano naturale, da appassionato competente: niente toni da televendita,
niente frasi fatte da IA, niente trattini lunghi, pochissime emoji (al massimo 3).

Regole sui fatti, da rispettare sempre:
- Marca, modello, referenza, anno, calibro, materiali e corredo li prendi SOLO dai dati
  forniti dal venditore. Non inventare mai referenze, anni, calibri o dati tecnici.
- Dalle foto descrivi solo ciò che si vede davvero: colore e finitura del quadrante,
  lunetta, cassa, bracciale o cinturino, segni d'uso visibili.
- Se le foto sembrano in contrasto con i dati (es. corredo indicato ma non visibile,
  condizioni diverse da quelle dichiarate, modello diverso), segnalalo in "avvisi".
- Se il prezzo non è indicato, scrivi "Prezzo in DM".

Rispondi SOLO con un oggetto JSON valido, senza testo prima o dopo, con questa forma:
{
  "didascalia": "testo completo del post",
  "hashtag": ["#esempio"],
  "storie": ["testo slide 1", "testo slide 2", "testo slide 3"],
  "risposta_dm": "risposta pronta per chi scrive in privato chiedendo info",
  "avvisi": ["eventuale incongruenza tra foto e dati"]
}
''';

/// Costruisce il testo della richiesta a partire dai dati certi.
String buildUserPrompt(WatchListing w, ShopProfile shop, {int photoCount = 0}) {
  final b = StringBuffer();
  b.writeln('Crea il post di vendita per questo orologio.');
  b.writeln();
  b.writeln('Dati certi forniti dal venditore:');
  for (final l in w.factLines()) {
    b.writeln(l);
  }
  final shopLines = shop.lines();
  if (shopLines.isNotEmpty) {
    b.writeln();
    b.writeln('Informazioni sulla pagina:');
    for (final l in shopLines) {
      b.writeln(l);
    }
  }
  b.writeln();
  if (photoCount > 0) {
    b.writeln('Ti allego $photoCount foto dell\'orologio reale in vendita.');
  } else {
    b.writeln('Non ci sono foto: basati solo sui dati, senza descrivere dettagli visivi.');
  }
  b.writeln();
  b.writeln('Didascalia:');
  b.writeln('- Prima riga: un gancio forte sotto i 120 caratteri '
      '(è l\'unica parte visibile prima di "... altro").');
  b.writeln('- Poi i dati essenziali, una riga ciascuno, facili da leggere.');
  b.writeln('- Poi 2-3 frasi su cosa rende interessante questo pezzo, basate sui dati e sulle foto.');
  b.writeln('- Chiudi con un invito a scrivere in DM per info o acquisto.');
  b.writeln('- Non mettere gli hashtag dentro la didascalia.');
  b.writeln();
  b.writeln('Hashtag: massimo 5, specifici (marca, modello, nicchia, città se indicata).');
  b.writeln('Storie: 3 slide brevi (massimo 12 parole ciascuna) per annunciare il pezzo.');
  return b.toString();
}

/// Indirizzo della chiamata generateContent dell'API Gemini.
Uri geminiEndpoint(String model) => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '${Uri.encodeComponent(model.trim())}:generateContent');

/// Corpo JSON della chiamata generateContent dell'API Gemini.
Map<String, dynamic> buildRequestBody({
  required String userPrompt,
  required List<ImagePart> images,
  double temperature = 0.8,
}) {
  return {
    'systemInstruction': {
      'parts': [
        {'text': kSystemPrompt},
      ],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          for (final img in images)
            {
              'inlineData': {
                'mimeType': img.mediaType,
                'data': img.base64Data,
              },
            },
          {'text': userPrompt},
        ],
      },
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'temperature': temperature,
    },
  };
}

class ImagePart {
  final String mediaType;
  final String base64Data;
  const ImagePart(this.mediaType, this.base64Data);
}

/// Riconosce il formato dai primi byte (JPEG, PNG, WebP, HEIC/HEIF:
/// i formati accettati da Gemini). Restituisce null se il formato non è supportato dall'API.
String? detectMediaType(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 && // R
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x46 && // F
      bytes[8] == 0x57 && // W
      bytes[9] == 0x45 && // E
      bytes[10] == 0x42 && // B
      bytes[11] == 0x50) {
    // P
    return 'image/webp';
  }
  // HEIC/HEIF: "ftyp" ai byte 4-7, poi il marchio del formato.
  if (bytes.length >= 12 &&
      bytes[4] == 0x66 && // f
      bytes[5] == 0x74 && // t
      bytes[6] == 0x79 && // y
      bytes[7] == 0x70) {
    // p
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (const ['heic', 'heix', 'hevc', 'hevx'].contains(brand)) {
      return 'image/heic';
    }
    if (const ['mif1', 'msf1', 'heif'].contains(brand)) return 'image/heif';
  }
  return null;
}
