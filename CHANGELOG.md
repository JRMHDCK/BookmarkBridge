# Changelog

Toutes les évolutions notables de BookmarkBridge sont documentées dans ce fichier.
Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
projet utilise le versionnement sémantique.

## Non publié

Aucun changement fonctionnel depuis le gel du moteur V1.

## 0.9.0-beta1 - 2026-07-29

### Ajouté

- Application macOS native SwiftUI, compilée avec Swift 6 et la concurrence stricte.
- Lecture réelle des favoris Safari et des profils Google Chrome.
- Autorisations persistantes App Sandbox par security-scoped bookmarks.
- Dashboard par source avec statistiques de favoris, dossiers et nœuds.
- Explorateur hiérarchique, fil d'Ariane et recherche globale multi-sources.
- Détection additive des favoris absents avec normalisation des URL et suppression
  des paramètres de suivi connus.
- Aperçu bidirectionnel des différences avant application.
- Sélection du profil Chrome cible ; les profils non inscriptibles sont clairement
  signalés en lecture seule.
- Application V1 dans le sens Safari → Chrome uniquement.
- Génération du JSON Chrome et de son checksum compatible `bookmark_codec`.
- Sauvegarde horodatée obligatoire, persistante et isolée par fichier de profil.
- Création ou remplacement atomique de `Bookmarks.bak`.
- Remplacement atomique du fichier `Bookmarks`.
- Restauration depuis la dernière sauvegarde du profil, y compris après réouverture
  de la fenêtre ou redémarrage de l'application.
- Rafraîchissement automatique du Dashboard et de l'aperçu après application ou
  restauration.
- États de progression, confirmation explicite et messages utilisateur localisés.

### Sécurité

- App Sandbox maintenu actif avec accès aux fichiers sélectionnés en lecture-écriture.
- Refus de la synchronisation et de la restauration lorsque Chrome est ouvert.
- Nouvelle vérification de Chrome immédiatement avant le remplacement final.
- Relecture du fichier `Bookmarks` courant avant chaque écriture.
- Filtrage idempotent des ajouts avec la même logique que l'aperçu.
- Conservation du handle de sauvegarde lorsque la transaction échoue après backup.
- Échec explicite si le security scope ou la création de `Bookmarks.bak` échoue.
- Aucun test n'accède aux favoris réels : fixtures et dossiers temporaires uniquement.

### Corrigé

- Accès App Sandbox en écriture au dossier Chrome autorisé.
- Création et remplacement de `Bookmarks.bak` dans le security scope du profil.
- Absence de doublons lors de deux applications successives.
- Nombre affiché aligné sur le nombre de favoris réellement écrits.
- Sauvegarde restaurable après fermeture de la fenêtre de synchronisation.
- Profil possédant un `AccountBookmarks` vide traité comme un profil local inscriptible.

### Limites connues de la V1

- Safari reste strictement en lecture seule.
- Les fichiers Chrome `AccountBookmarks` ne sont jamais modifiés.
- Les profils avec deux stockages non vides restent en lecture seule.
- Les ajouts Chrome sont placés dans « Autres favoris » sans reconstruire les
  dossiers d'origine.
