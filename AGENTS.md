# AGENTS.md — BookmarkBridge

Ce document est la **source de vérité** pour le développement de BookmarkBridge. Toute contribution doit s'y conformer. Il est destiné à évoluer avec le projet.

---

## 1. Vision

BookmarkBridge est une **application macOS native** qui synchronise de manière **fiable, transparente et non destructive** les favoris entre **Safari** et **Google Chrome**.

L'utilisateur doit avoir une confiance absolue dans l'outil : **aucune perte de favori ne doit jamais être possible**. La fiabilité et la sécurité des données priment sur la richesse fonctionnelle et sur la rapidité de livraison.

---

## 2. Objectifs

### Objectifs produit
- Lire les favoris de Safari et de Chrome.
- Détecter les différences (ajouts, suppressions, déplacements, renommages).
- Proposer une synchronisation **prévisualisable** avant application.
- Écrire les favoris de façon sûre, idempotente et réversible.

### Objectifs d'ingénierie
- Base de code **maintenable, testable et lisible**.
- Architecture claire (**MVVM**), respect des principes **SOLID**.
- **Swift 6** avec concurrence stricte.
- Couverture de tests élevée sur la logique métier.
- Historique Git propre et traçable.

### Non-objectifs (à ce stade)
- Support d'autres navigateurs (Firefox, Edge…).
- Synchronisation cloud / multi-machines.
- Fonctionnalités temps réel en arrière-plan.

---

## 3. Principe fondateur — « Lecture seule avant toute écriture »

C'est la règle **la plus importante** du projet. Elle prime sur toute autre considération.

1. **Phase 1 — Lecture seule (read-only).** Tant que la lecture, la modélisation en mémoire, la détection de différences et la **prévisualisation (dry-run)** ne sont pas complètes, éprouvées et couvertes par des tests, **aucun code n'écrit dans les favoris d'un navigateur**.
2. **Aucune écriture destructive sans sauvegarde.** Toute opération d'écriture doit être précédée d'une **sauvegarde horodatée** des fichiers/état d'origine, restaurable.
3. **Dry-run par défaut.** Toute opération de synchronisation doit d'abord pouvoir s'exécuter en mode simulation, produisant un rapport des changements **sans rien modifier**.
4. **Idempotence & réversibilité.** Réappliquer une synchronisation ne doit pas dupliquer ni corrompre. Chaque écriture doit être annulable.
5. **Fermeture des navigateurs.** L'écriture ne doit être tentée que dans un état sûr (navigateur cible fermé ou via une API supportée), jamais en concurrence avec le navigateur.
6. **Consentement explicite.** Aucune écriture n'est déclenchée sans une action explicite et informée de l'utilisateur, après affichage de la prévisualisation.

> Toute Pull Request introduisant une capacité d'écriture doit démontrer explicitement le respect de ces six points.

---

## 4. Contraintes techniques connues

- **Cible :** macOS 26.5+, application SwiftUI native.
- **App Sandbox activé** (`ENABLE_APP_SANDBOX = YES`). L'accès aux favoris de Safari (`~/Library/Safari/Bookmarks.plist`) et de Chrome (`~/Library/Application Support/Google/Chrome/.../Bookmarks`) utilise des **security-scoped bookmarks** persistants et l'entitlement user-selected read-write. Ne jamais désactiver le sandbox pour contourner un problème.
- **Format des données :**
  - Safari : `Bookmarks.plist` (property list binaire).
  - Chrome : fichier `Bookmarks` (JSON) accompagné de `Bookmarks.bak` et d'un champ de checksum.
- Ces détails doivent être **isolés derrière des abstractions** (voir SOLID / MVVM) afin que la logique métier ne dépende jamais directement d'un format de fichier.

Le projet compile en **Swift 6** avec `SWIFT_STRICT_CONCURRENCY = complete`.

---

## 5. Architecture — MVVM

L'application suit le patron **Model – View – ViewModel**, complété par une couche **Services** pour l'accès aux données externes.

```
┌─────────────┐     observe      ┌──────────────┐     appelle     ┌───────────────┐
│    View     │ ───────────────▶ │  ViewModel   │ ──────────────▶ │   Services     │
│  (SwiftUI)  │ ◀─────────────── │ (@Observable)│ ◀────────────── │  (protocoles)  │
└─────────────┘   état / binding └──────────────┘     résultats   └───────────────┘
                                         │                                 │
                                         ▼                                 ▼
                                   ┌──────────┐                    ┌──────────────┐
                                   │  Models  │                    │ Repositories │
                                   │ (valeurs)│                    │  (I/O réel)  │
                                   └──────────┘                    └──────────────┘
```

### Responsabilités
- **View (SwiftUI)** — présentation uniquement. Aucune logique métier, aucun I/O. Se contente d'afficher l'état du ViewModel et de router les intentions utilisateur.
- **ViewModel** (`@Observable`, `@MainActor`) — état de présentation et orchestration. Ne connaît **pas** les formats de fichiers ni les navigateurs concrets ; ne dépend que de **protocoles** de services.
- **Model** — types de domaine **immuables** (`struct`, `enum`), sans dépendance à un framework UI. Ex. : `Bookmark`, `BookmarkFolder`, `BookmarkTree`, `SyncPlan`, `SyncDiff`.
- **Services / Repositories** — accès aux navigateurs (lecture/écriture), parsing, sauvegarde. Exposés via des **protocoles** ; les implémentations concrètes sont injectées.

### Règles d'architecture
- Dépendances dirigées vers l'intérieur : `View → ViewModel → Protocoles`. Les détails (formats, fichiers) dépendent des abstractions, jamais l'inverse.
- **Injection de dépendances** systématique (constructeur). Aucun singleton caché, aucun accès global à l'état.

### Organisation modulaire

Le code est organisé en trois zones aux responsabilités distinctes — **App** (composition), **Core** (métier, sans UI), **Features** (modules d'interface verticaux), plus **Shared** (transverse UI/utilitaires). Cette séparation renforce SOLID : le métier (`Core`) ne dépend jamais de l'UI, et chaque feature est un module autonome (sa `View` + son `ViewModel`).

```
BookmarkBridge/
├── App/                    # Point d'entrée (@main), composition root, injection des dépendances
├── Core/                   # Domaine & logique métier — AUCUNE dépendance à SwiftUI
│   ├── Models/             # Types de domaine immuables & Sendable (Bookmark, BookmarkTree, SyncPlan…)
│   ├── Services/           # Protocoles + implémentations métier
│   │   ├── Reading/        # Lecture des favoris (protocole BookmarkReading, lecteurs par navigateur)
│   │   ├── Writing/        # Transaction additive Chrome V1
│   │   ├── Diffing/        # Détection des différences & planification de synchronisation
│   │   └── Backup/         # Sauvegarde & restauration horodatées
│   ├── Parsers/            # Encodage/décodage des formats (Safari .plist, Chrome JSON)
│   ├── Security/           # App Sandbox, security-scoped bookmarks, accès fichiers
│   └── Utilities/          # Helpers purement métier, sans UI
├── Features/               # Modules d'interface verticaux (chacun : Views + ViewModels)
│   ├── Dashboard/          # Vue d'ensemble de l'état des favoris
│   ├── Synchronisation/    # Prévisualisation (dry-run) & déclenchement de la synchro
│   ├── Settings/           # Préférences de l'application
│   └── Logs/               # Historique des opérations & journal d'audit
├── Shared/                 # Éléments transverses à plusieurs features
│   ├── Components/         # Composants SwiftUI réutilisables
│   ├── Extensions/         # Extensions Swift/SwiftUI transverses
│   └── Resources/          # Ressources partagées (hors Assets.xcassets)
└── Assets.xcassets/        # Catalogue d'assets (icône, couleurs)
```

### Règles de dépendances entre zones
- `Features` et `App` peuvent dépendre de `Core` et de `Shared`.
- `Core` **ne dépend de rien d'autre** (ni `Features`, ni `Shared`, ni SwiftUI) : c'est le cœur métier testable en isolation.
- `Shared` ne contient aucune logique métier ni état d'application.
- Aucune dépendance croisée entre features : toute mutualisation passe par `Core` (métier) ou `Shared` (UI).

---

## 6. Principes SOLID

- **S — Single Responsibility.** Chaque type a une seule raison de changer. Un parser Safari ne fait que parser Safari.
- **O — Open/Closed.** Ajouter un navigateur = ajouter une implémentation de protocole, sans modifier l'existant.
- **L — Liskov.** Toute implémentation d'un protocole doit être substituable sans casser les invariants (utile pour les mocks de test).
- **I — Interface Segregation.** Des protocoles fins et ciblés (`BookmarkReading`, `ChromeBookmarkApplying`, `BookmarkBackup`) plutôt qu'un protocole monolithique.
- **D — Dependency Inversion.** Le code de haut niveau (ViewModels) dépend d'abstractions ; les implémentations concrètes sont injectées à la composition root.

---

## 7. Conventions Swift 6

- **Swift 6, concurrence stricte** (`SWIFT_STRICT_CONCURRENCY = complete`).
- **Sendable & isolation :** le projet utilise l'isolation `MainActor` par défaut (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, « approachable concurrency »). En conséquence, **toute la couche `Core` (modèles et protocoles) est déclarée `nonisolated`** : ce sont des données/contrats purs, indépendants de l'UI, utilisables hors du main actor. Les types de domaine sont `Sendable` et immuables ; les ViewModels restent `@MainActor` ; les I/O s'exécutent hors du main actor (via `actor` ou fonctions `async`). Voir [`Docs/adr/0004-isolation-concurrence.md`](Docs/adr/0004-isolation-concurrence.md).
- **`async`/`await`** pour toute opération asynchrone ; **pas** de complétions par closures pour du nouveau code, pas de `DispatchQueue` manuel sauf nécessité justifiée.
- **Immutabilité par défaut :** `let` plutôt que `var` ; `struct`/`enum` plutôt que `class` sauf besoin de référence/isolation (`actor`).
- **Typage fort :** pas de « stringly-typed ». Utiliser `enum`, types dédiés, et identifiants typés.
- **Gestion d'erreurs :** erreurs typées (`enum: Error`) explicites ; **jamais** de `try!` ni de `fatalError` en chemin de production ; `force unwrap` (`!`) interdit hors tests et invariants prouvés.
- **Optionnels :** privilégier `guard let`, `if let`, `??`. Pas de `!`.
- **Nommage :** API en anglais, `UpperCamelCase` pour les types, `lowerCamelCase` pour le reste, noms explicites et complets.
- **Accès :** membre le plus restrictif possible (`private`, `fileprivate`) ; `public`/`internal` seulement si nécessaire.
- **Style :** respect du guide [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). Un formateur/linter (SwiftFormat / SwiftLint) pourra être adopté ; en attendant, cohérence avec le code existant.

---

## 8. Stratégie Git

### Branches
- `main` — toujours compilable, toujours verte (tests OK). Pas de commit direct de fonctionnalité.
- `feature/<description-courte>` — nouvelle fonctionnalité.
- `fix/<description-courte>` — correction.
- `chore/<description-courte>` — maintenance, outillage, gouvernance.

### Commits — Conventional Commits
Format : `type(scope): sujet impératif court`

Types : `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `build`, `ci`.

Exemples :
```
feat(reader): add Safari bookmark plist parser
test(diff): cover folder rename detection
chore(git): add .gitignore and governance files
docs: document read-only-before-write principle
```

Règles : commits **atomiques** et cohérents, sujet ≤ 72 caractères, corps expliquant le *pourquoi* si nécessaire. `main` reste toujours dans un état compilable.

### Pull Requests
- Une PR = une intention. Description claire : quoi, pourquoi, comment tester.
- Toute PR touchant à l'**écriture** des favoris doit démontrer le respect de la section 3.
- CI verte (build + tests) exigée avant fusion.
- Fusion en préservant un historique lisible (squash ou rebase selon convention d'équipe).

### Ne jamais versionner
Fichiers utilisateur/dérivés (voir `.gitignore`) : `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, secrets. Les schémas partagés vont dans `xcshareddata/`.

---

## 9. Stratégie de tests

Framework : **Swift Testing** (`import Testing`, macros `@Test` / `#expect` / `#require`).

### Pyramide
1. **Tests unitaires** (majorité) — logique métier pure : parsing, diff, planification de synchronisation, modèles. Rapides, déterministes, sans I/O réel.
2. **Tests d'intégration** — services concrets contre des **fixtures** (fichiers d'exemple Safari/Chrome), en dossier temporaire, jamais contre les données réelles de l'utilisateur.
3. **Tests d'UI** (`BookmarkBridgeUITests`) — parcours critiques uniquement. Nécessitent une session graphique (ils lancent l'app) ; en environnement headless, ne cibler que le target unitaire : `xcodebuild test -only-testing:BookmarkBridgeTests`.

### Règles
- La logique métier est testée via des **protocoles mockés** (grâce à l'injection de dépendances).
- **Aucun test ne lit ni n'écrit dans les vrais favoris du système.** Utiliser des fixtures et des répertoires temporaires.
- Priorité de couverture : **détection de différences** et **planification de synchronisation** (cœur du risque).
- Tout `fix` de bug s'accompagne d'un test de non-régression.
- Tests déterministes : pas de dépendance à l'horloge réelle, au réseau, ni à l'ordre d'exécution.
- L'écriture Chrome est couverte par des tests de **dry-run**, de **sauvegarde/restauration**, de sécurité et d'**idempotence**.

---

## 10. Règles de qualité du code

- **Lisibilité d'abord.** Le code doit se lire comme le code environnant : même densité de commentaires, même nommage, mêmes idiomes.
- **Fonctions courtes**, à responsabilité unique. Complexité maîtrisée.
- **Pas de code mort**, pas de code commenté laissé en place, pas de `print` de debug en production.
- **Commentaires utiles :** expliquer le *pourquoi*, pas le *quoi*. Documenter les invariants et les décisions non évidentes.
- **Pas d'avertissements du compilateur** tolérés (« zero-warning policy »).
- **Gestion d'erreurs explicite** ; jamais d'échec silencieux.
- **Aucun secret** en dur dans le code.
- **DRY sans sur-abstraction** : factoriser quand la duplication est réelle, pas par anticipation.
- Toute décision d'architecture significative est documentée (dans ce fichier ou une ADR dédiée).

---

## 11. Règles pour les outils de contribution

- Le moteur de synchronisation V1 est **gelé** : ne pas le modifier sans demande explicite de l'utilisateur.
- **Respecter la phase « lecture seule avant écriture »** (section 3) : ne proposer aucune écriture dans les favoris sans les garde-fous décrits.
- **Ne pas modifier** de fichier Swift sans demande explicite.
- **Ne pas désactiver** l'App Sandbox ni les protections de sécurité pour simplifier une tâche.
- Proposer, expliquer, puis **attendre validation** pour les changements structurants (réglages de build, dépendances, architecture).
- Préférer les changements petits, revus et testés.

---

## 12. État actuel du projet

- **BookmarkBridge V1 est fonctionnellement finalisée et son moteur de synchronisation est gelé.**
- Application macOS SwiftUI, Swift 6, concurrence stricte, architecture **App / Core / Features / Shared**.
- App Sandbox actif avec `ENABLE_USER_SELECTED_FILES = readwrite`, entitlement user-selected read-write et bookmarks app-scope.
- Lecture réelle Safari et Chrome multi-profils via security-scoped bookmarks persistants.
- Dashboard, exploration hiérarchique, fil d'Ariane et recherche globale opérationnels.
- Diff additif et aperçu avant application.
- Écriture limitée à Safari → fichier Chrome local `Bookmarks` ; Safari et `AccountBookmarks` restent en lecture seule.
- Transaction Chrome : navigateur fermé, backup obligatoire, relecture disque, filtrage idempotent, checksum, `Bookmarks.bak`, remplacement atomique et restauration persistante.
- Dashboard et aperçu rechargés automatiquement après application ou restauration.
- Tests Swift Testing sur logique pure, fixtures et dossiers temporaires ; aucun test ne touche aux favoris réels.
- Validation fonctionnelle manuelle terminée pour synchronisation, absence de doublons, backup/restauration, sandbox et UX.
- Documentation d'architecture et ADR à jour jusqu'à l'ADR-0005.
