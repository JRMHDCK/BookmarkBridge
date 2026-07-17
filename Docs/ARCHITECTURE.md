# Architecture — BookmarkBridge V1

Ce document décrit l'architecture effectivement mise en œuvre dans la V1. Les
règles de contribution complètes restent définies dans [`../AGENTS.md`](../AGENTS.md)
et son équivalent [`../CLAUDE.md`](../CLAUDE.md).

## Vue d'ensemble

BookmarkBridge suit MVVM avec une couche de services injectés :

```text
View SwiftUI
    │ intentions / bindings
    ▼
ViewModel @MainActor @Observable
    │ protocoles Core
    ▼
Services et modèles nonisolated / Sendable
    │
    ├── parsing et diff purs
    └── I/O fichiers et security scopes
```

Les vues ne lisent aucun fichier et n'exécutent aucun algorithme métier. Les
ViewModels orchestrent les services et publient un état de présentation. Les
détails Safari, Chrome et App Sandbox restent dans `Core` ou dans les adaptateurs
macOS de `App`.

## Organisation

```text
BookmarkBridge/
├── App/
│   ├── BookmarkBridgeApp.swift       # @main et composition
│   ├── AppDependencies.swift         # graphe de production
│   └── Access/                       # NSOpenPanel et détection des apps macOS
├── Core/
│   ├── Models/                       # valeurs immuables du domaine
│   ├── Parsers/                      # Safari plist et Chrome JSON/checksum
│   ├── Security/                     # bookmarks et security scopes
│   └── Services/
│       ├── Reading/                  # découverte et lecture des sources
│       ├── Searching/                # recherche pure
│       ├── Diffing/                  # comparaison additive
│       ├── Syncing/                  # construction de l'aperçu
│       ├── Backup/                   # sauvegarde et restauration disque
│       └── Writing/                  # transaction Chrome V1
├── Features/
│   ├── Dashboard/
│   ├── Explorer/
│   ├── Search/
│   └── Synchronisation/
├── Shared/                           # UI et formatage transverses
└── Assets.xcassets/
```

`Settings` et `Logs` sont encore des emplacements réservés sans fonctionnalité V1.

## Flux de lecture

1. `DashboardViewModel` demande aux `BrowserSourceProviding` les lecteurs disponibles.
2. Safari et Chrome localisent leurs sources via le security-scoped bookmark
   précédemment autorisé.
3. `SandboxFileAccessProvider` ouvre l'accès pour la durée de la lecture.
4. Les décodeurs transforment les octets en `BookmarkTree` immuable.
5. Le Dashboard conserve l'arbre par `BookmarkSourceID` et calcule les statistiques.

Chrome expose un lecteur par profil. `DefaultChromeProfileLocator` distingue :

- `Bookmarks` local, inscriptible en V1 ;
- `AccountBookmarks`, lu mais jamais modifié ;
- deux stockages non vides, état ambigu et lecture seule.

Un `AccountBookmarks` vide n'empêche pas l'utilisation du fichier local `Bookmarks`.

## Diff et aperçu

`AdditiveBookmarkDiffer` compare deux arbres avec `BookmarkMatchKey`. La clé :

- normalise le schéma, l'hôte et le slash terminal ;
- retire les paramètres de suivi connus ;
- conserve les paramètres et fragments significatifs.

`BookmarkSyncPlanner` produit un aperçu additif dans les deux directions. La V1
n'applique toutefois que le plan Safari → Chrome. Aucune suppression, aucun
déplacement et aucun renommage n'est écrit.

## Transaction Chrome V1

`ChromeBookmarkApplier` orchestre la seule écriture de la V1 :

1. refus si Chrome est ouvert ;
2. validation et ouverture du security scope du profil ;
3. sauvegarde privée horodatée obligatoire ;
4. relecture du fichier `Bookmarks` courant ;
5. filtrage idempotent avec `BookmarkMatchKey` ;
6. génération du JSON et du checksum Chrome ;
7. création ou remplacement atomique de `Bookmarks.bak` ;
8. seconde vérification que Chrome est fermé ;
9. remplacement atomique de `Bookmarks` ;
10. fermeture systématique du scope avec `defer`.

Le résultat contient le handle de sauvegarde et le nombre réel de favoris écrits.
Si une étape échoue après la sauvegarde, son handle reste disponible.

## Sauvegarde et restauration

`FileBookmarkBackup` écrit sous `Application Support/BookmarkBridge/Backups` :

- une copie privée du fichier original ;
- un sidecar JSON contenant le handle et l'URL originale ;
- permissions 0700 pour les dossiers et 0600 pour les fichiers.

Les sauvegardes sont recherchées par navigateur et, pour l'interface, par URL exacte
du fichier du profil. Le dernier handle peut donc être retrouvé après réouverture de
la fenêtre ou redémarrage de l'application sans risquer une restauration croisée.

La restauration vérifie que Chrome est fermé, exige l'ouverture du même security
scope, remplace atomiquement le fichier original, recharge le profil puis actualise
le Dashboard.

## App Sandbox

Le sandbox reste activé. La cible possède :

- `com.apple.security.app-sandbox` ;
- `com.apple.security.files.user-selected.read-write` ;
- `com.apple.security.files.bookmarks.app-scope`.

L'utilisateur autorise explicitement le fichier Safari et le dossier racine Chrome.
Les autorisations persistantes sont stockées sous forme de security-scoped bookmarks.
Le droit lecture-écriture n'implique aucune écriture Safari : la politique V1 reste
appliquée par les services et l'interface.

## Concurrence

La cible utilise Swift 6, `SWIFT_STRICT_CONCURRENCY = complete` et l'isolation
`MainActor` par défaut. Les modèles et protocoles `Core` sont explicitement
`nonisolated`, immuables et `Sendable`. Les ViewModels sont `@MainActor`.

Voir [ADR-0004](adr/0004-isolation-concurrence.md).

## Composition et dépendances

`AppDependencies.bootstrap()` construit les lecteurs réels, le moteur de diff, le
store d'autorisations et le store de sauvegarde. `BookmarkBridgeApp` injecte ensuite
les services macOS et l'applicateur Chrome dans le Dashboard.

Règles de dépendances :

- `Core` ne dépend ni de SwiftUI, ni de `Features`, ni de `Shared` ;
- `Features` dépend de `Core` et `Shared` ;
- `Shared` ne contient aucune logique métier ;
- `App` est l'unique composition root.

## Tests

La logique métier, les parseurs, la sécurité, le diff, l'écriture, l'idempotence et
la restauration sont couverts avec Swift Testing. Les intégrations utilisent des
fixtures et des dossiers temporaires ; aucun test ne touche aux favoris réels.

Les parcours critiques ont également fait l'objet d'une validation manuelle dans
l'application sandboxée.

## Décisions associées

- [ADR-0002](adr/0002-lecture-seule-avant-ecriture.md) — garde-fous préalables à l'écriture ;
- [ADR-0003](adr/0003-architecture-modulaire.md) — séparation App/Core/Features/Shared ;
- [ADR-0004](adr/0004-isolation-concurrence.md) — isolation Swift 6 ;
- [ADR-0005](adr/0005-ecriture-chrome-v1.md) — ouverture contrôlée de l'écriture Chrome.
