/// Application-wide constants.
///
/// Replace [kUnsplashAccessKey] with your own key from
/// https://unsplash.com/developers before running in production.
library;

/// Unsplash Access Key for meal image search.
const String kUnsplashAccessKey = 'YOUR_UNSPLASH_ACCESS_KEY';

/// Google Gemini API Key from Google AI Studio (aistudio.google.com).
/// Can be provided via --dart-define=GEMINI_API_KEY=your_key or in AI Settings in-app.
const String kGeminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: 'YOUR_GEMINI_API_KEY',
);

