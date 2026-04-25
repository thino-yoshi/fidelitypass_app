# Changelog — Qarta App

## [2026-04-25] — Mise à jour majeure UI & fonctionnalités

### Navigation & Design
- **Navbar frosted glass** : barre de navigation translucide avec effet de flou (BackdropFilter), contenu qui s'étend derrière
- **Edge-to-edge Android** : suppression de la barre de navigation système (mode immersif)
- **Logo Q en filigrane** : watermark transparent du logo dans le header

### Profil utilisateur
- **Photo de profil** : sélection depuis la galerie, upload sur Supabase Storage, affichage immédiat
- **Informations personnelles** : bottom sheet avec Nom, Email, Téléphone modifiables
  - Champs verrouillés pour les comptes Google (email non modifiable)
  - Numéro de téléphone stocké en local
  - Badge "Google" affiché pour les comptes OAuth
- **Sécurité** : option "Changer le mot de passe" masquée pour les comptes Google

### Récompenses
- **Modal récompenses** : le pill "Récompense" ouvre une modale au lieu de rediriger vers l'historique
- **Carte récompense dans la modale** : affichage des cartes prêtes à être réclamées (tampons atteints)
- **Détection en temps réel** : polling toutes les 2 secondes sur `/cards/me`
  - Dès qu'un tampon est ajouté par le marchand → fermeture automatique du QR modal
  - Fermeture du modal récompenses si ouvert
  - Rafraîchissement des cartes et retour sur l'écran des cartes

### Backend (FastAPI)
- `GET /users/me` : retourne `is_google` (détection compte OAuth)
- `PATCH /users/me` : mise à jour nom/email (bloqué pour comptes Google)
- `POST /auth/google` : retourne `email` et `is_google: true`

### Technique
- Ajout package `image_picker: ^1.1.2`
- Permissions Android : `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`
- `SharedPreferences` pour session (email, is_google, téléphone, chemin image)
- `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`
