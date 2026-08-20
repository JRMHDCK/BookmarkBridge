# Site BookmarkBridge

Première version statique de la page d’accueil de [bookmarkbridge.fr](https://bookmarkbridge.fr/).

## Structure

- `index.html` : contenu et structure sémantique de la page ;
- `download.html` : téléchargement et guide visuel d’ouverture Gatekeeper ;
- `styles.css` : mise en page, design et responsive ;
- `script.js` : menu mobile, en-tête et année du pied de page ;
- `assets/images/` : icônes locales et captures Gatekeeper optimisées.
- `downloads/` : DMG, guide PDF et somme de contrôle SHA-256 ;
- `.htaccess` : types MIME, cache et réglages Apache compatibles OVH ;
- `robots.txt` et `sitemap.xml` : indexation du site officiel.

## Prévisualisation locale

Ouvrir directement `index.html` dans un navigateur, ou lancer un serveur HTTP local depuis ce dossier :

```sh
python3 -m http.server 8080
```

Puis ouvrir `http://localhost:8080`.

Le site ne requiert aucune installation, dépendance ou compilation.
