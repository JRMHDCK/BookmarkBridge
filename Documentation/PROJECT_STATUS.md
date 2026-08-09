# État technique du projet BookmarkBridge

Ce document donne à un développeur reprenant le projet une vue synthétique de
l'architecture, des garanties actuelles et de la suite du travail. Les règles de
contribution normatives restent définies dans [`../AGENTS.md`](../AGENTS.md).

## Vue d'ensemble

BookmarkBridge est une application macOS native SwiftUI écrite en Swift 6. Elle
synchronise de façon additive les favoris Safari vers un fichier `Bookmarks`
Chrome local, après prévisualisation explicite. Le moteur V1 et l'interface sont
gelés avant la première bêta.

Le projet applique MVVM et l'injection de dépendances :

```text
View SwiftUI
    → ViewModel @MainActor
        → protocoles et modèles Core nonisolated / Sendable
            → services, adaptateurs et dépôts injectés
```

La cible macOS utilise la concurrence stricte, l'App Sandbox et des
security-scoped bookmarks persistants. Aucune dépendance tierce n'est intégrée.

## Modules

- `BookmarkBridge/App` : point d'entrée, composition root, navigation et
  adaptateurs macOS d'autorisation.
- `BookmarkBridge/Core` : modèles, parsing, sécurité, lecture, comparaison,
  planification, sauvegarde, persistance et moteur BSE. Cette zone ne dépend pas
  de SwiftUI.
- `BookmarkBridge/Features` : écrans verticaux Dashboard, Explorer, Search,
  Synchronisation, Settings et About, avec leurs ViewModels.
- `BookmarkBridge/Shared` : design system, composants SwiftUI et formatage
  transverses, sans logique métier.
- `BookmarkBridgeTests` : tests Swift Testing unitaires et d'intégration fondés
  sur des fixtures et des dossiers temporaires.
- `BookmarkBridgeUITests` : parcours critiques de l'application macOS.
- `QA` : datasets synthétiques, scénarios déterministes, runner unique et
  rapports non versionnés.

Les détails des flux sont documentés dans
[`../Docs/ARCHITECTURE.md`](../Docs/ARCHITECTURE.md), et les décisions
structurantes dans [`../Docs/adr`](../Docs/adr/README.md).

## Jalons historiques

| Commit | Jalon |
|---|---|
| `7952b88` | Adoption de Swift 6 et de l'architecture modulaire. |
| `c935940` | Lecture, exploration et recherche globales intégrées. |
| `17cdfb8` | Adaptateur d'écriture Safari ajouté au moteur générique. |
| `9f873bf` | Première implémentation complète du BSE. |
| `56d161c` | Workflow de synchronisation et navigation intégrés à l'UI. |
| `37493b7` | Finitions natives macOS et micro-interactions. |
| `4949b54` | Plateforme QA automatisée et réutilisable. |
| `3ca16bf` | Interface native macOS finalisée avant bêta. |

Utiliser `git log --oneline` pour l'historique complet et les commits de détail.

## État actuel

- Version configurée : `0.9.2` (build `1`), bêta publique `v0.9.2-beta`.
- Cible : macOS 26.5+, Swift 6, concurrence stricte.
- Configurations Xcode : Debug et Release ; Release compile en whole-module,
  génère un dSYM, retire les symboles du produit installé et élimine le code mort.
- Archive Release : binaire universel Apple Silicon et Intel.
- App Sandbox actif avec accès user-selected read-write et bookmarks app-scope.
- Lecture Safari et Chrome multi-profils opérationnelle.
- Synchronisation bidirectionnelle Safari et Chrome, avec sélection préalable
  des profils, dossiers et favoris.
- Aperçu obligatoire, fermeture du navigateur cible, sauvegarde, écriture atomique,
  validation, idempotence et restauration sont en place.
- Chrome `AccountBookmarks` reste en lecture seule.
- Interface, navigation, moteur BSE et logique métier sont gelés.
- La plateforme QA s'exécute avec `QA/Scripts/run-qa.sh`.

Les tests automatisés ne lisent et n'écrivent jamais les favoris réels. Les
rapports QA sont générés sous `QA/Reports/` et ne sont pas versionnés.

## Reprendre le projet

Validation complète :

```bash
QA/Scripts/run-qa.sh
```

Build ou test ciblé :

```bash
xcodebuild build \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project BookmarkBridge.xcodeproj \
  -scheme BookmarkBridge \
  -destination 'platform=macOS' \
  -only-testing:BookmarkBridgeTests \
  CODE_SIGNING_ALLOWED=NO
```

Avant toute modification, lire `AGENTS.md`. Toute évolution d'écriture doit
préserver la prévisualisation, le consentement explicite, la sauvegarde,
l'idempotence, la réversibilité et les garde-fous liés aux navigateurs.

## Prochaines étapes

La prochaine étape de livraison est la préparation opérationnelle de la bêta :

1. configurer l'identité de signature et le profil de distribution ;
2. produire, signer et notariser l'archive Release ;
3. vérifier l'installation sur un compte macOS propre ;
4. effectuer un smoke test manuel avec des données synthétiques ;
5. distribuer la bêta et centraliser les retours sans dégeler le moteur hors
   correction bloquante.

Les évolutions produit V2 sont volontairement différées. La première capacité
métier recensée est l'écriture Safari, puis la synchronisation bidirectionnelle ;
elles exigent une nouvelle phase de conception et de validation des garanties de
sécurité. Voir [`../Docs/TODO-V2.md`](../Docs/TODO-V2.md).
