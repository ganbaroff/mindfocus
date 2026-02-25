import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = "AIzaSyCI6yL1wCCzzKWU3GQV2S1hFmExHDY5fJo";
  final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    for (var model in data['models']) {
      print(
          'Model: ${model['name']} - supported methods: ${model['supportedGenerationMethods']}');
    }
  } else {
    print('Failed to load models: ${response.statusCode} - ${response.body}');
  }
}
