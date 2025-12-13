import 'package:flutter_gemini/flutter_gemini.dart';

/// Extended GenerationConfig that supports JSON schema for structured output
class ExtendedGenerationConfig extends GenerationConfig {
  final String? responseMimeType;
  final Map<String, dynamic>? responseJsonSchema;

  ExtendedGenerationConfig({
    super.stopSequences,
    super.temperature,
    super.maxOutputTokens,
    super.topP,
    super.topK,
    this.responseMimeType,
    this.responseJsonSchema,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    
    if (responseMimeType != null) {
      json['responseMimeType'] = responseMimeType;
    }
    
    if (responseJsonSchema != null) {
      json['responseSchema'] = responseJsonSchema;
    }
    
    return json;
  }
}
