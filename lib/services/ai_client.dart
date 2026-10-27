import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/post_result.dart';
import '../core/prompt_builder.dart';

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// Client per l'API Gemini di Google (piano gratuito).
class AiClient {
  final http.Client _http;
  AiClient({http.Client? client}) : _http = client ?? http.Client();

  Future<PostResult> generate({
    required String apiKey,
    required String model,
    required String userPrompt,
    required List<ImagePart> images,
  }) async {
    final body = buildRequestBody(userPrompt: userPrompt, images: images);

    http.Response res;
    try {
      res = await _http
          .post(
            geminiEndpoint(model),
            headers: {
              'x-goog-api-key': apiKey.trim(),
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw AiException(
          'Nessuna risposta in 2 minuti. Controlla la connessione e riprova.');
    } on SocketException {
      throw AiException('Nessuna connessione a internet.');
    } on http.ClientException catch (e) {
      throw AiException('Errore di rete: ${e.message}');
    }

    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) {
      throw AiException(friendlyApiError(res.statusCode, text));
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw AiException('Risposta inattesa dal servizio.');
    }
    final blocked = blockedReason(decoded);
    if (blocked != null) throw AiException(blocked);

    final answer = extractText(decoded);
    try {
      return PostResult.parse(answer);
    } on FormatException {
      throw AiException('Risposta non nel formato previsto. Riprova a generare.');
    }
  }
}
