import 'dart:convert';
import 'package:http/http.dart' as http;

const _groqApiKey =
    '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';
const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

class ExplanationService {
  static String _buildPrompt(String objectName, String level) {
    switch (level) {
      case 'simple':
        return "Explain what a '$objectName' is in 2-3 simple sentences for a 10-year-old. Use very easy words.";
      case 'advanced':
        return "Provide a detailed explanation of '$objectName' in 4-5 sentences for a college student. Include scientific or technical aspects, history, and interesting facts.";
      default: // medium
        return "Explain what a '$objectName' is in 3-4 sentences for a high school student. Include basic facts and uses.";
    }
  }

  /// Calls Groq's Llama model directly from Flutter — no backend involved.
  static Future<String> explain(String objectName, String level) async {
    final payload = {
      'model': 'llama-3.1-8b-instant',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a helpful educational assistant. Give clear, accurate, engaging explanations.',
        },
        {
          'role': 'user',
          'content': _buildPrompt(objectName, level),
        },
      ],
      'max_tokens': 200,
      'temperature': 0.7,
    };

    final response = await http
        .post(
          Uri.parse(_groqUrl),
          headers: {
            'Authorization': 'Bearer $_groqApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['choices'][0]['message']['content'] as String).trim();
    } else {
      throw Exception('Groq error ${response.statusCode}: ${response.body}');
    }
  }
}
