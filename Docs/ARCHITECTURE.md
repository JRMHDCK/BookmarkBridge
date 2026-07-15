# Architecture — BookmarkBridge

> Ce document détaille l'architecture. La **source de vérité** des règles reste
> [`../CLAUDE.md`](../CLAUDE.md) ; ce fichier en développe la mise en œuvre concrète.
> Il décrit une **cible d'architecture** : aucune logique métier n'est encore implémentée.

## 1. Vue d'ensemble

BookmarkBridge suit le patron **MVVM**, complété par une couche **Services** et une
séparation modulaire en quatre zones :

- **App** — point d'entrée (`@main`), composition root, injection des dépendances.
- **Core** — domaine et logique métier, **sans aucune dépendance à SwiftUI**.
- **Features** — modules d'interface verticaux (chacun : `View` + `ViewModel`).
- **Shared** — éléments UI et utilitaires transverses à plusieurs features.

Objectif : un cœur métier (`Core`) testable en isolation, des features autonomes, et
une frontière nette entre logique et présentation.

## 2. Arborescence

```
BookmarkBridge/
├── App/                    # @main, composition root, injection des dépendances
├── Core/                   # Domaine & métier — AUCUNE dépendance à SwiftUI
│   ├── Models/             # Types de domaine immuables & Sendable
│   ├── Services/
│   │   ├── Reading/        # Lecture des favoris (protocole BookmarkReading)
│   │   ├── Writing/        # Écriture des favoris (phase 2 — BookmarkWriting)
│   │   ├── Diffing/        # Différences & planification de synchronisation
│   │   └── Backup/         # Sauvegarde & restauration horodatées
│   ├── Parsers/            # Encodage/décodage (Safari .plist, Chrome JSON)
│   ├── Security/           # Sandbox, security-scoped bookmarks, accès fichiers
│   └── Utilities/          # Helpers purement métier
├── Features/               # Modules d'interface verticaux
│   ├── Dashboard/          # Vue d'ensemble de l'état des favoris
│   ├── Synchronisation/    # Prévisualisation (dry-run) & déclenchement
│   ├── Settings/           # Préférences
│   └── Logs/               # Historique & journal d'audit
├── Shared/                 # Transverse à plusieurs features
│   ├── Components/         # Composants SwiftUI réutilisables
│   ├── Extensions/         # Extensions Swift/SwiftUI
│   └── Resources/          # Ressources partagées
└── Assets.xcassets/        # Catalogue d'assets
```

## 3. Flux de données (MVVM)

```
┌─────────────┐   observe / intents   ┌──────────────┐   appelle   ┌───────────────┐
│    View     │ ────────────────────▶ │  ViewModel   │ ──────────▶ │   Services     │
│  (SwiftUI)  │ ◀──────────────────── │ (@Observable │ ◀────────── │  (protocoles)  │
│  Features/  │      état publié      │  @MainActor) │  résultats  │    Core/       │
└─────────────┘                       └──────────────┘             └───────────────┘
                                              │                              │
                                              ▼                              ▼
                                        ┌──────────┐                 ┌──────────────┐
                                        │  Models  │                 │   Parsers    │
                                        │ (Core)   │                 │  (Core)      │
                                        └──────────┘                 └──────────────┘
```

- **View** : présentation uniquement. Aucun I/O, aucune logique métier.
- **ViewModel** (`@Observable`, `@MainActor`) : état de présentation et orchestration.
  Dépend **uniquement de protocoles** `Core`, jamais d'implémentations concrètes.
- **Services / Core** : logique métier derrière des protocoles ; implémentations
  injectées depuis la composition root (`App`).

## 4. Règles de dépendances

| Zone       | Peut dépendre de              | Ne doit PAS dépendre de                     |
|------------|-------------------------------|---------------------------------------------|
| `App`      | `Core`, `Features`, `Shared`  | —                                           |
| `Features` | `Core`, `Shared`              | autres `Features`                           |
| `Shared`   | `Core` (types uniquement)     | `Features`, état d'application              |
| `Core`     | rien (Foundation seulement)   | SwiftUI, `Features`, `Shared`, `App`        |

- Dépendances dirigées vers l'intérieur : les détails (formats de fichiers, navigateurs)
  dépendent des abstractions, jamais l'inverse (**DIP**).
- Aucune dépendance croisée entre features : toute mutualisation passe par `Core`
  (métier) ou `Shared` (UI).

## 5. Protocoles envisagés (cible — non implémentés)

Conformément à l'**Interface Segregation**, des protocoles fins et ciblés. Signatures
données à titre indicatif ; elles seront définies lors de l'étape « modèles &
protocoles ».

```swift
// Core/Services/Reading — la seule capacité nécessaire à la phase « lecture seule ».
protocol BookmarkReading: Sendable {
    func readBookmarkTree() async throws -> BookmarkTree
}

// Core/Services/Diffing — comparaison de deux arbres, sans effet de bord.
protocol BookmarkDiffing: Sendable {
    func diff(source: BookmarkTree, target: BookmarkTree) -> SyncPlan
}

// Core/Services/Backup — sauvegarde préalable à toute écriture (phase 2).
protocol BookmarkBackup: Sendable {
    func backup(_ location: BrowserLocation) async throws -> BackupHandle
    func restore(_ handle: BackupHandle) async throws
}

// Core/Services/Writing — introduit UNIQUEMENT en phase 2, jamais avant.
protocol BookmarkWriting: Sendable {
    func apply(_ plan: SyncPlan, dryRun: Bool) async throws -> SyncReport
}
```

## 6. Principe fondateur — « Lecture seule avant toute écriture »

L'architecture matérialise ce principe (détaillé en section 3 de [`../CLAUDE.md`](../CLAUDE.md)) :

1. La phase 1 ne dépend que de `BookmarkReading` et `BookmarkDiffing` — aucune
   capacité d'écriture n'existe dans le graphe de dépendances.
2. `BookmarkWriting` n'est introduit qu'en phase 2, derrière une sauvegarde
   (`BookmarkBackup`) et un mode **dry-run** par défaut.
3. Le module `Features/Synchronisation` prévisualise un `SyncPlan` avant toute
   application, sur consentement explicite de l'utilisateur.

## 7. Concurrence (Swift 6)

- Isolation `MainActor` par défaut (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- Couche `Core` (modèles + protocoles) : **`nonisolated`**, `Sendable`, immuable —
  indépendante du main actor et de l'UI (voir `adr/0004-isolation-concurrence.md`).
- ViewModels (`Features`) : `@MainActor`.
- I/O et parsing : hors du main actor (`actor` ou fonctions `async`).
- Concurrence stricte activée (`SWIFT_STRICT_CONCURRENCY = complete`).

## 8. Tests

Voir la section 9 de [`../CLAUDE.md`](../CLAUDE.md). En résumé : logique `Core`
testée en isolation via protocoles mockés ; services concrets testés contre des
**fixtures** en dossier temporaire ; **jamais** contre les favoris réels du système.

## 9. Prochaines étapes

1. ~~Définir les **modèles de domaine** (`Core/Models`)~~ — fait.
2. ~~Définir les **protocoles** de services (lecture, diff, backup, parsing, sécurité)~~ — fait.
3. ~~Compléter l'**architecture MVVM** (composition root, ViewModels de base, injection)~~ — fait.
4. ~~Écrire les **tests unitaires de base** (modèles + ViewModels via doubles)~~ — fait.
5. **Puis seulement** : implémenter la lecture (Safari, Chrome), le diff, la
   prévisualisation, et enfin l'écriture (phase 2, derrière backup + dry-run).

### Types définis (phase actuelle)

- **Modèles** (`Core/Models`) : `Browser`, `BookmarkID`, `Bookmark`, `BookmarkFolder`,
  `BookmarkNode`, `BookmarkTree`, `BrowserLocation`, `BookmarkError`, `SyncChange`,
  `SyncPlan`, `SyncReport`, `BackupHandle`.
- **Protocoles** : `BookmarkReading`, `BookmarkSourceLocating`, `BookmarkDiffing`,
  `BookmarkBackup`, `BookmarkDecoding`, `FileAccessProviding`.
- **Absent volontairement** : `BookmarkWriting` (phase 2 — ADR-0002).

### Ossature MVVM (phase actuelle)

- **Composition root** : `App/AppDependencies` (graphe assemblé une fois, injecté).
- **ViewModel** : `Features/Dashboard/DashboardViewModel` (`@MainActor @Observable`),
  dépend uniquement de `BookmarkReading` ; `BrowserBookmarkSummary` comme modèle de présentation.
- **Vue** : `Features/Dashboard/DashboardView`, purement présentation.
- **Doubles in-memory** (previews/tests/amorçage, sans I/O) : `InMemoryBookmarkReader`,
  `InMemoryBookmarkDiffer`, `InMemoryBackupStore`. À remplacer par les implémentations
  réelles une fois les tests en place.
