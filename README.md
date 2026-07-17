# BookmarkBridge

BookmarkBridge est une application macOS native, écrite en SwiftUI et Swift 6,
qui synchronise les favoris de Safari vers Google Chrome de manière additive,
prévisualisable et réversible.

## État du projet

La V1 est fonctionnellement finalisée. Elle a été validée manuellement sur les
parcours critiques : autorisation App Sandbox, synchronisation Safari → Chrome,
idempotence, sauvegarde, restauration et rafraîchissement automatique.

Le moteur de synchronisation V1 est gelé. La V1 n'écrit jamais dans Safari et ne
modifie pas les fichiers `AccountBookmarks` des profils Chrome connectés.

Version applicative préparée : **1.0 (build 1)**. Le tag Git proposé pour la
publication est `v1.0.0`.

## Fonctionnalités V1

- Lecture réelle des favoris Safari (`Bookmarks.plist`).
- Découverte et lecture des profils Chrome (`Bookmarks` et détection
  d'`AccountBookmarks`).
- Dashboard avec statistiques par source : favoris, dossiers et nœuds.
- Exploration hiérarchique avec fil d'Ariane.
- Recherche globale multi-sources.
- Aperçu des différences avant toute écriture.
- Sélection du profil Chrome cible.
- Synchronisation additive Safari → Chrome uniquement.
- Déduplication par la même normalisation d'URL lors de l'aperçu et de l'écriture.
- Sauvegarde horodatée obligatoire et `Bookmarks.bak` avant remplacement atomique.
- Restauration persistante, associée au profil Chrome exact.
- Refus de toute écriture ou restauration pendant l'exécution de Chrome.
- App Sandbox avec autorisations persistantes par security-scoped bookmarks.

## Garanties de sécurité

Toute écriture Chrome respecte la séquence suivante :

1. Chrome doit être fermé.
2. Le security scope du dossier autorisé doit être ouvert en écriture.
3. Une sauvegarde privée et restaurable est créée.
4. Le fichier `Bookmarks` courant est relu depuis le disque.
5. Seuls les favoris réellement absents sont générés.
6. `Bookmarks.bak` reçoit l'état précédent.
7. Chrome est vérifié une seconde fois.
8. Le fichier est remplacé atomiquement.

Une seconde application sans changement n'ajoute aucun doublon.

## Prérequis

| Outil | Version |
|---|---|
| macOS | 26.5 ou version ultérieure |
| Xcode | Version stable compatible avec le SDK macOS 26.5 |
| Swift | 6, concurrence stricte |

## Compilation et tests

```bash
xcodebuild build \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -destination 'platform=macOS' \
  -only-testing:BookmarkBridgeTests \
  CODE_SIGNING_ALLOWED=NO
```

Les tests utilisent exclusivement des fixtures et des dossiers temporaires. Ils
ne lisent ni n'écrivent les favoris réels de l'utilisateur.

## Architecture

Le projet suit une architecture MVVM organisée en quatre zones :

- `App` : point d'entrée, composition et injection des dépendances ;
- `Core` : modèles, parsing, lecture, diff, sauvegarde, écriture et sécurité ;
- `Features` : Dashboard, Explorer, Search et Synchronisation ;
- `Shared` : composants et utilitaires d'interface partagés.

Voir [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) et les
[décisions d'architecture](Docs/adr/README.md).

## Limites de la V1

- Synchronisation appliquée uniquement de Safari vers Chrome.
- Aucune écriture dans Safari.
- `AccountBookmarks` et les profils Chrome ambigus restent en lecture seule.
- Les ajouts sont placés dans la racine Chrome « Autres favoris » ; la structure
  de dossiers d'origine n'est pas reconstruite.
- Aucune synchronisation cloud ou en arrière-plan.

Les évolutions différées sont recensées dans [Docs/TODO-V2.md](Docs/TODO-V2.md).

## Documentation du projet

- [AGENTS.md](AGENTS.md) et [CLAUDE.md](CLAUDE.md) : règles de développement ;
- [CONTRIBUTING.md](CONTRIBUTING.md) : processus de contribution ;
- [CHANGELOG.md](CHANGELOG.md) : contenu des versions ;
- [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) : architecture mise en œuvre ;
- [Docs/adr](Docs/adr/README.md) : décisions structurantes.

## Licence

BookmarkBridge est distribué sous licence MIT. Voir [LICENSE](LICENSE).
