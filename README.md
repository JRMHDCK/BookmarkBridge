# BookmarkBridge

Application macOS native (**SwiftUI + Swift 6**) qui synchronise de manière fiable les favoris entre **Safari** et **Google Chrome**.

> ⚠️ **Statut : amorçage du projet.** La fonctionnalité de synchronisation n'est pas encore implémentée. Le dépôt est en cours de mise en place (gouvernance, architecture, conventions). Voir [`CLAUDE.md`](CLAUDE.md) pour les règles de développement.

---

## Vision

Offrir aux utilisateurs macOS un pont **fiable, transparent et non destructif** entre les favoris de leurs navigateurs, sans jamais risquer la perte de données.

## Principe directeur : lecture seule avant toute écriture

Aucune écriture dans les favoris d'un navigateur n'est réalisée tant que la chaîne complète de **lecture**, de **modélisation** et de **prévisualisation (dry-run)** n'est pas éprouvée et couverte par des tests. La sécurité des données de l'utilisateur prime sur toute fonctionnalité. Voir la section dédiée dans [`CLAUDE.md`](CLAUDE.md).

---

## Prérequis

| Outil | Version |
|-------|---------|
| macOS | 26.5+ |
| Xcode | dernière version stable |
| Swift | 6 (mode concurrence strict) |

## Démarrage

```bash
git clone <url>
cd BookmarkBridge
open BookmarkBridge.xcodeproj
```

Compiler et lancer : `⌘R`. Lancer les tests : `⌘U`.

## Structure du dépôt

```
BookmarkBridge/            # Cible application (SwiftUI)
BookmarkBridgeTests/       # Tests unitaires (Swift Testing)
BookmarkBridgeUITests/     # Tests d'interface
BookmarkBridge.xcodeproj/  # Projet Xcode
CLAUDE.md                  # Règles de développement, architecture, conventions
README.md                  # Ce fichier
```

## Documentation

Toutes les règles d'ingénierie (architecture MVVM, SOLID, conventions Swift 6, stratégie Git, stratégie de tests, qualité du code) sont centralisées dans **[`CLAUDE.md`](CLAUDE.md)**.

## Licence

À définir.
