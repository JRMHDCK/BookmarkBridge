# ADR-0004 — Isolation par défaut MainActor, couche Core nonisolated

- Statut : Accepté
- Date : 2026-07-15

## Contexte

Le projet est configuré avec `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
(mode « approachable concurrency » d'Xcode 26 / Swift 6). Chaque déclaration sans
isolation explicite est donc inférée `@MainActor`. Or la couche `Core` (modèles et
protocoles) doit être exécutable **hors du main actor** (lecture de fichiers, parsing,
diff en tâche de fond) et rester indépendante de l'UI. Sans intervention, les
conformances synthétisées (`Equatable`, `Hashable`) des modèles deviennent
`@MainActor`, ce qui casse leur usage depuis des contextes non isolés (erreur
« main actor-isolated conformance … cannot be used in nonisolated context »).

## Décision

- Conserver `MainActor` comme isolation **par défaut** du projet (idéal pour la couche
  SwiftUI : `App`, `Features`, `Shared`).
- Déclarer **explicitement `nonisolated`** tous les types et protocoles de `Core`
  (modèles immuables `Sendable`, protocoles de services). `Core` ne dépend jamais du
  main actor.
- Les ViewModels (`Features`) restent `@MainActor` ; les I/O s'exécutent hors du main
  actor via `actor` ou fonctions `async`.

## Conséquences

- La couche métier est utilisable et testable depuis n'importe quel contexte de
  concurrence, sans blocage du main actor.
- Coût : un mot-clé `nonisolated` explicite sur chaque type/protocole de `Core`
  (intention claire et documentée).
- Alignement avec la direction Apple : `MainActor` par défaut pour l'app, `nonisolated`
  pour le domaine.
