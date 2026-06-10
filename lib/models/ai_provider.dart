enum AiProvider { gemini, claude, openai }

extension AiProviderExt on AiProvider {
  String get displayName => switch (this) {
        AiProvider.gemini => 'Google Gemini',
        AiProvider.claude => 'Anthropic Claude',
        AiProvider.openai => 'OpenAI',
      };

  String get storageKey => switch (this) {
        AiProvider.gemini => 'ai_api_key_gemini',
        AiProvider.claude => 'ai_api_key_claude',
        AiProvider.openai => 'ai_api_key_openai',
      };

  String get keyHint => switch (this) {
        AiProvider.gemini => 'aistudio.google.com',
        AiProvider.claude => 'console.anthropic.com',
        AiProvider.openai => 'platform.openai.com',
      };
}