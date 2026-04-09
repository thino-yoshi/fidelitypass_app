// Environnement actif : 'dev' | 'staging' | 'prod'
const String _env = String.fromEnvironment('ENV', defaultValue: 'prod');

const Map<String, String> _apiUrls = {
  'dev': 'http://10.0.2.2:8000',       // Émulateur Android → localhost
  'staging': 'https://fidelitypass-staging.up.railway.app',
  'prod': 'https://fidelitypass-production.up.railway.app',
};

final String apiUrl = _apiUrls[_env] ?? _apiUrls['prod']!;
