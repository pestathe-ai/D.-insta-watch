import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:insta_watch/core/post_result.dart';
import 'package:insta_watch/core/prompt_builder.dart';
import 'package:insta_watch/core/watch_listing.dart';

void main() {
  group('WatchListing', () {
    test('righe solo per i campi compilati, corredo sempre presente', () {
      const w = WatchListing(brand: 'Omega', model: 'Speedmaster', hasBox: true);
      final lines = w.factLines();
      expect(lines, contains('- Marca: Omega'));
      expect(lines, contains('- Modello: Speedmaster'));
      expect(lines, contains('- Corredo: Solo scatola'));
      expect(lines.any((l) => l.startsWith('- Anno')), isFalse);
      expect(lines.any((l) => l.startsWith('- Prezzo')), isFalse);
    });

    test('full set', () {
      const w = WatchListing(hasBox: true, hasPapers: true);
      expect(w.corredo, startsWith('Full set'));
    });

    test('isEmpty', () {
      expect(const WatchListing().isEmpty, isTrue);
      expect(const WatchListing(reference: '116610LN').isEmpty, isFalse);
    });
  });

  group('prompt', () {
    test('include dati, pagina e numero di foto', () {
      const w = WatchListing(brand: 'Rolex', reference: '116610LN', price: '11.500 €');
      const shop = ShopProfile(pageName: 'Tempo Ritrovato', city: 'Torino');
      final p = buildUserPrompt(w, shop, photoCount: 3);
      expect(p, contains('- Referenza: 116610LN'));
      expect(p, contains('- Prezzo: 11.500 €'));
      expect(p, contains('- Nome pagina: Tempo Ritrovato'));
      expect(p, contains('3 foto'));
    });

    test('senza foto chiede di non descrivere dettagli visivi', () {
      final p = buildUserPrompt(
          const WatchListing(brand: 'Seiko'), const ShopProfile());
      expect(p, contains('Non ci sono foto'));
    });

    test('corpo richiesta Gemini: immagini prima del testo, JSON in uscita', () {
      final body = buildRequestBody(
        userPrompt: 'ciao',
        images: const [ImagePart('image/jpeg', 'AAAA')],
      );
      final decoded = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
      expect(decoded['systemInstruction']['parts'][0]['text'], isNotEmpty);
      final parts = decoded['contents'][0]['parts'] as List;
      expect(parts.length, 2);
      expect(parts[0]['inlineData']['mimeType'], 'image/jpeg');
      expect(parts[0]['inlineData']['data'], 'AAAA');
      expect(parts[1], {'text': 'ciao'});
      expect(decoded['generationConfig']['responseMimeType'], 'application/json');
    });

    test('endpoint', () {
      expect(
        geminiEndpoint('gemini-3.8-flash').toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent',
      );
    });
  });

  group('detectMediaType', () {
    test('jpeg, png, webp, sconosciuto', () {
      expect(detectMediaType([0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
      expect(detectMediaType([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
          'image/png');
      expect(
        detectMediaType(
            [...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WEBP')]),
        'image/webp',
      );
      expect(
        detectMediaType([0, 0, 0, 0x18, ...ascii.encode('ftypheic')]),
        'image/heic',
      );
      expect(detectMediaType([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]), isNull);
    });
  });

  group('PostResult.parse', () {
    test('JSON pulito', () {
      final r = PostResult.parse(jsonEncode({
        'didascalia': 'Un classico.',
        'hashtag': ['#rolex', 'submariner'],
        'storie': ['Nuovo arrivo', 'Full set'],
        'risposta_dm': 'Ciao! Disponibile.',
        'avvisi': [],
      }));
      expect(r.caption, 'Un classico.');
      expect(r.hashtags, ['#rolex', '#submariner']);
      expect(r.stories.length, 2);
      expect(r.warnings, isEmpty);
      expect(r.fullCaption, 'Un classico.\n\n#rolex #submariner');
    });

    test('tollera blocco ```json e testo intorno', () {
      const raw = 'Ecco il post:\n```json\n{"didascalia": "Ok", "hashtag": "#a #b"}\n```';
      final r = PostResult.parse(raw);
      expect(r.caption, 'Ok');
      expect(r.hashtags, ['#a', '#b']);
      expect(r.stories, isEmpty);
    });

    test('errore se manca la didascalia o il JSON', () {
      expect(() => PostResult.parse('niente'), throwsFormatException);
      expect(() => PostResult.parse('{"hashtag": []}'), throwsFormatException);
    });
  });

  group('hashtag', () {
    test('massimo 5, senza doppioni, con #', () {
      final t = normalizeHashtags(
          ['rolex', '#Rolex', '#watch, #orologi', 'a b c d e f']);
      expect(t.length, 5);
      expect(t.first, '#rolex');
      expect(t.where((x) => x.toLowerCase() == '#rolex').length, 1);
      expect(t.every((x) => x.startsWith('#')), isTrue);
    });
  });

  group('risposte API', () {
    test('estrae il testo saltando il ragionamento', () {
      final r = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'penso...', 'thought': true},
                {'text': '{"didascalia":"x"}'},
              ],
            },
            'finishReason': 'STOP',
          }
        ]
      };
      expect(extractText(r), '{"didascalia":"x"}');
      expect(blockedReason(r), isNull);
    });

    test('risposta bloccata o vuota', () {
      expect(blockedReason({'promptFeedback': {'blockReason': 'SAFETY'}}),
          contains('bloccata'));
      expect(blockedReason({'candidates': []}), isNotNull);
      expect(
        blockedReason({
          'candidates': [
            {'finishReason': 'SAFETY'}
          ]
        }),
        contains('SAFETY'),
      );
      expect(extractText({'candidates': []}), '');
    });

    test('messaggi di errore', () {
      expect(
        friendlyApiError(400,
            '{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}'),
        contains('Chiave API'),
      );
      expect(
        friendlyApiError(429,
            '{"error":{"code":429,"message":"Quota exceeded","status":"RESOURCE_EXHAUSTED"}}'),
        contains('Limite gratuito'),
      );
      expect(friendlyApiError(404, '{}'), contains('Modello'));
      expect(friendlyApiError(503, ''), contains('sovraccarico'));
    });
  });
}
