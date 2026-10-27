import 'dart:convert';

/// Post generato dall'IA.
class PostResult {
  final String caption;
  final List<String> hashtags;
  final List<String> stories;
  final String dmReply;
  final List<String> warnings;

  const PostResult({
    required this.caption,
    required this.hashtags,
    required this.stories,
    required this.dmReply,
    required this.warnings,
  });

  /// Didascalia pronta da incollare su Instagram (testo + hashtag in fondo).
  String get fullCaption {
    final tags = hashtags.join(' ');
    if (tags.isEmpty) return caption.trim();
    return '${caption.trim()}\n\n$tags';
  }

  /// Interpreta il testo restituito dal modello. Tollera testo extra prima o
  /// dopo il JSON e blocchi ```json. Lancia [FormatException] se non trova
  /// una didascalia.
  static PostResult parse(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('Risposta senza JSON');
    }
    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! Map) {
      throw const FormatException('JSON non valido');
    }
    final caption = (decoded['didascalia'] ?? '').toString().trim();
    if (caption.isEmpty) {
      throw const FormatException('Didascalia mancante');
    }
    return PostResult(
      caption: caption,
      hashtags: normalizeHashtags(_stringList(decoded['hashtag'])),
      stories: _stringList(decoded['storie']),
      dmReply: (decoded['risposta_dm'] ?? '').toString().trim(),
      warnings: _stringList(decoded['avvisi']),
    );
  }

  static List<String> _stringList(Object? v) {
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return const [];
  }
}

/// Aggiunge il "#" se manca, toglie spazi e doppioni, massimo 5
/// (limite attuale di Instagram).
List<String> normalizeHashtags(List<String> input, {int max = 5}) {
  final seen = <String>{};
  final out = <String>[];
  for (final t in input) {
    for (final part in t.split(RegExp(r'\s+'))) {
      var tag = part.trim().replaceAll(RegExp(r'[,;]'), '');
      if (tag.isEmpty) continue;
      if (!tag.startsWith('#')) tag = '#$tag';
      if (tag.length < 2) continue;
      if (seen.add(tag.toLowerCase())) out.add(tag);
      if (out.length >= max) return out;
    }
  }
  return out;
}

/// Estrae il testo dalla risposta di generateContent (Gemini):
/// candidates[0].content.parts[].text, saltando le parti di "ragionamento".
String extractText(Map<String, dynamic> response) {
  final candidates = response['candidates'];
  if (candidates is! List || candidates.isEmpty) return '';
  final first = candidates.first;
  if (first is! Map) return '';
  final content = first['content'];
  if (content is! Map) return '';
  final parts = content['parts'];
  if (parts is! List) return '';
  return parts
      .whereType<Map>()
      .where((p) => p['thought'] != true && p['text'] != null)
      .map((p) => p['text'].toString())
      .join('\n');
}

/// Se Gemini ha bloccato la richiesta o la risposta, restituisce un
/// messaggio comprensibile; altrimenti null.
String? blockedReason(Map<String, dynamic> response) {
  final feedback = response['promptFeedback'];
  if (feedback is Map && feedback['blockReason'] != null) {
    return 'Richiesta bloccata dai filtri di Google '
        '(${feedback['blockReason']}). Prova con altre foto.';
  }
  final candidates = response['candidates'];
  if (candidates is! List || candidates.isEmpty) {
    return 'Nessuna risposta dal modello. Riprova.';
  }
  final first = candidates.first;
  final reason = first is Map ? first['finishReason']?.toString() : null;
  if (reason == 'SAFETY' || reason == 'PROHIBITED_CONTENT' ||
      reason == 'BLOCKLIST' || reason == 'RECITATION') {
    return 'Risposta bloccata dai filtri di Google ($reason). Riprova.';
  }
  return null;
}

/// Messaggio d'errore comprensibile a partire da codice HTTP e corpo
/// (formato errori Google: {"error": {"code", "message", "status"}}).
String friendlyApiError(int status, String body) {
  String detail = '';
  String code = '';
  try {
    final j = jsonDecode(body);
    if (j is Map && j['error'] is Map) {
      final e = j['error'] as Map;
      detail = (e['message'] ?? '').toString();
      code = (e['status'] ?? '').toString();
    }
  } catch (_) {}
  final lower = detail.toLowerCase();
  if (lower.contains('api key') ||
      status == 401 ||
      code == 'UNAUTHENTICATED' ||
      code == 'PERMISSION_DENIED') {
    return 'Chiave API non valida. Controllala nelle Impostazioni.';
  }
  if (status == 429 || code == 'RESOURCE_EXHAUSTED') {
    return 'Limite gratuito raggiunto. Aspetta un minuto; '
        'se continua, riprova domani o cambia modello nelle Impostazioni.';
  }
  if (status == 404 || code == 'NOT_FOUND') {
    return 'Modello non più disponibile. Scegline un altro nelle Impostazioni.';
  }
  if (lower.contains('location') || code == 'FAILED_PRECONDITION') {
    return 'Il piano gratuito non è disponibile così: $detail';
  }
  if (status == 413 || lower.contains('too large') || lower.contains('size')) {
    return 'Foto troppo pesanti. Prova con meno foto.';
  }
  if (status >= 500) {
    return 'Il servizio è momentaneamente sovraccarico. Riprova tra poco.';
  }
  if (detail.isNotEmpty) return 'Errore ($status): $detail';
  return 'Errore imprevisto ($status).';
}
