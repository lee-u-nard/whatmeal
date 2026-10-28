// Optional image-service configuration supplied at build time.
// Values embedded in a mobile binary are extractable; never use this for
// privileged server credentials. Gemini uses Firebase AI or the user's key.
const String kUnsplashAccessKey = String.fromEnvironment('UNSPLASH_ACCESS_KEY');
