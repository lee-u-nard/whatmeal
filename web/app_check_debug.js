// Explicit local development only. Firebase generates the private token in the
// browser; this file must never contain a credential. Register it only for the
// intended development Firebase web app. Ordinary launches use reCAPTCHA.
(() => {
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(location.hostname);
  const requested = new URLSearchParams(location.search).get('appCheckDebug');
  if (local && requested === 'true') {
    self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  }
})();
