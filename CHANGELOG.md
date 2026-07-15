# Changelog

Toutes les évolutions notables de ce projet sont documentées dans ce fichier.

Le format s'appuie sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
et le projet suit le [Semantic Versioning](https://semver.org/lang/fr/).

## [Non publié]

Phase d'amorçage : mise en place de la gouvernance et de l'architecture, **avant**
toute implémentation de lecture ou de synchronisation des favoris.

### Ajouté
- Fichiers de gouvernance : `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `LICENSE` (MIT), `CHANGELOG.md`.
- `.gitignore` adapté à macOS / Xcode / Swift.
- Documentation d'architecture dans `Docs/` (`ARCHITECTURE.md` et journal des décisions `adr/`, ADR-0001 à 0004).
- Arborescence modulaire **App / Core / Features / Shared** (dossiers de structure, sans code métier).
- **Modèles de domaine** (`Core/Models`) immuables et `Sendable` : `Browser`, `BookmarkID`,
  `Bookmark`, `BookmarkFolder`, `BookmarkNode`, `BookmarkTree`, `BrowserLocation`,
  `BookmarkError`, `SyncChange`, `SyncPlan`, `SyncReport`, `BackupHandle`.
- **Protocoles de services** (`Core`) : `BookmarkReading`, `BookmarkSourceLocating`,
  `BookmarkDiffing`, `BookmarkBackup`, `BookmarkDecoding`, `FileAccessProviding` —
  contrats read-only uniquement, sans implémentation.
- **Ossature MVVM** : composition root `AppDependencies`, `DashboardViewModel`,
  `DashboardView` câblée, `BrowserBookmarkSummary`.
- **Doubles in-memory** des protocoles (`InMemoryBookmarkReader`,
  `InMemoryBookmarkDiffer`, `InMemoryBackupStore`) pour faire tourner l'app et les
  previews sans accès fichier.
- **Tests unitaires de base** (Swift Testing) : modèles de domaine, modèles de
  synchronisation et `DashboardViewModel` (succès / liste vide / échec) via les doubles.
- **Lecture Safari — localisation** : `SafariBookmarkSourceLocator` (calcul pur du
  chemin `~/Library/Safari/Bookmarks.plist`, home injectable), avec tests.
- **Lecture Safari — fixtures** : `SafariBookmarksFixture`, générateur programmatique
  et anonymisé d'un `Bookmarks.plist` (binaire, déterministe) couvrant barre des
  favoris, dossiers imbriqués, dossier vide, liste de lecture, titre vide, URL
  inhabituelle et caractères Unicode ; tests du format brut (10).
- **Lecture Safari — parseur** : `SafariBookmarkDecoder` (`BookmarkDecoding`), décodage
  pur `Data` → `BookmarkTree` immuable, sans accès fichier. Percent-encode
  automatiquement les URL Unicode et ne rejette que les entrées irrécupérables ;
  `capturedAt` laissé en sentinelle (`.distantPast`), horodaté par le reader. Tests (14).
- **Accès fichier sandbox (lecture seule)** : API `FileAccessProviding` refactorée en
  accès à portée délimitée `withReadOnlyAccess { }` (fermeture systématique via
  `defer`), `SandboxFileAccessProvider` et l'abstraction injectable
  `SecurityScopedFileControlling` (+ implémentation système). Encapsule
  `start/stopAccessingSecurityScopedResource`, indépendant de Safari. Tests (7).
- **Lecture Safari — orchestrateur** : `SafariBookmarkReader` (`BookmarkReading`), pur
  orchestrateur (localisation → accès lecture seule → lecture des octets → décodage →
  horodatage `capturedAt`), sans logique de parsing ni UI. Dépendances injectables
  (locator, accès, décodeur, lecture d'octets, horloge). Tests d'intégration sur fichier
  temporaire + propagation d'erreurs et fermeture systématique de l'accès (7).
- **Accès réel Safari — entitlement & erreur** : fichier `BookmarkBridge.entitlements`
  avec `com.apple.security.files.bookmarks.app-scope` (+ app-sandbox et user-selected
  read-only conservés), câblé via `CODE_SIGN_ENTITLEMENTS` ; droits vérifiés dans la
  signature. Ajout du cas `BookmarkError.authorizationRequired(Browser)`.
- **Accès réel Safari — persistance** : protocole `BookmarkStore` (stockage de `Data`
  uniquement) et `ApplicationSupportBookmarkStore` (fichier privé versionné sous
  `Application Support/BookmarkBridge/`, écriture atomique, permissions 0700/0600,
  création du dossier à la demande, gestion des données absentes/corrompues, purge).
  Répertoire injectable ; tests exclusivement en dossier temporaire.
- **Accès réel Safari — bookmark security-scoped** : protocoles
  `SecurityScopedBookmarkCreating` / `SecurityScopedBookmarkResolving` (+ type
  `ResolvedBookmark` exposant `isStale`) et implémentations système
  (`.withSecurityScope` read-only). Doubles de test réutilisables ; tests du type,
  des doubles (frais/périmé/erreur) et du chemin d'erreur du resolver réel.
- **Accès réel Safari — locator autorisé** : `AuthorizedSafariSourceLocator`
  (`BookmarkSourceLocating`) orchestrant `BookmarkStore` + resolver + creator :
  bookmark valide → localisation ; périmé → recréation + sauvegarde automatique
  (best-effort) ; absent/corrompu/irrésoluble → `authorizationRequired(.safari)`.
  Aucun accès fichier, aucune UI, aucune dépendance au reader/décodeur. Tests (9).
- **Accès réel Safari — coordinateur d'autorisation** : protocole `SafariAccessAuthorizing`
  (seam UI, `@MainActor`) + `SafariAccessCoordinator` orchestrant autorisation →
  validation stricte du fichier (`Library/Safari/Bookmarks.plist`) → création du bookmark
  read-only → persistance → retour de l'URL. `SafariAccessError` (cancelled / wrongFile /
  bookmarkCreationFailed / persistenceFailed). Aucun décodage/lecture/parsing. Tests via
  faux authorizer, sans NSOpenPanel réel (6).
- **Accès réel Safari — adaptateur NSOpenPanel** : `OpenPanelSafariAccessAuthorizer`
  (`SafariAccessAuthorizing`, AppKit), panneau restreint à un seul fichier (dossiers et
  sélection multiple interdits), validation stricte du nom `Bookmarks.plist`
  (`wrongFile` sinon), annulation → `cancelled`. Ne crée/persiste/lit/décode rien.
  Présentation du panneau injectable ; logique de mapping testée sans NSOpenPanel réel (4).
- **Accès réel Safari — validation de la chaîne** : test d'intégration headless exerçant
  la chaîne réelle complète (coordinator → creator/store réels → locator autorisé →
  accès sandbox lecture seule → reader → decoder → `BookmarkTree`) sur un fichier
  temporaire, avec redémarrage simulé et preuve read-only (taille + date inchangées).
  Validation manuelle réalisée avec succès sur le vrai `~/Library/Safari/Bookmarks.plist`
  (31 dossiers, 849 favoris, bookmark persistant OK après redémarrage, aucun souci TCC).
- **Accès réel Safari — câblage** : `AppDependencies.bootstrap()` branche désormais le
  vrai `SafariBookmarkReader` (via `AuthorizedSafariSourceLocator` + `SandboxFileAccessProvider`
  + `SafariBookmarkDecoder`), Safari uniquement ; store et creator exposés pour le futur
  flux d'autorisation (couche App). `inApplicationSupport()` rendu non-throwing (dossier
  créé paresseusement). Harnais de diagnostic temporaire retiré (le test d'intégration de
  bout en bout est conservé comme régression).
- **Dashboard — état & action d'autorisation (par navigateur)** : `DashboardViewModel`
  refondu en état **par navigateur** (`[BrowserState]` : `loading` / `loaded` /
  `authorizationRequired` / `failed`) — extensible à Chrome/Firefox/Edge. Détection de
  `authorizationRequired` dans `load()`, action `authorize(_:)` (succès → rechargement,
  annulation → retour silencieux au prompt, erreur → `failed`). Nouveau protocole
  `BookmarkAuthorizationRequesting` (abstraction UI-agnostique, injectée). `DashboardView`
  adaptée a minima (rendu par navigateur + bouton « Autoriser »). Tests (9).
- **Dashboard — câblage de l'autorisation Safari** : adaptateur `SafariAuthorizationRequester`
  (`App/Access`, `#if os(macOS)`) enveloppant `SafariAccessCoordinator` (annulation → `false`,
  succès → `true`, erreur réelle propagée). Assemblage dans `BookmarkBridgeApp` (couche App,
  macOS) : coordinateur construit depuis `bookmarkStore` + `bookmarkCreator` +
  `OpenPanelSafariAccessAuthorizer`, injecté dans le `DashboardViewModel`. Tests de
  l'adaptateur (4).
- **Dashboard UI (palier 1)** : `BrowserBookmarkSummary` étendu avec `folderCount` et
  `nodeCount` (dossiers + favoris), comptés dans le modèle de présentation (parcours
  hors de la vue). Tests de comptage (3).
- **Dashboard UI (palier 2)** : `DashboardViewModel` — `retry(_:)` (relance le seul
  navigateur concerné, sans prompt), `reloadAll()` (relance tous les navigateurs, ne
  redemande jamais d'autorisation), `isLoading` (pour désactiver l'actualisation), et
  mapping des erreurs en messages FR simples et non techniques. Tests (8).
- **Dashboard UI (palier 3)** : réécriture de `DashboardView` — cartes `GroupBox` par
  navigateur dans un `ScrollView`, 4 états (chargement / autorisation requise / chargé /
  erreur), bouton « Autoriser l'accès… » (autorisation requise seulement), « Réessayer »
  (erreur seulement), toolbar « Actualiser » (désactivée pendant un chargement), badge
  « Lecture seule », statistiques Dossiers/Favoris/Nœuds, date via `Date.FormatStyle`,
  icônes SF Symbols par navigateur, état vide, libellés d'accessibilité, previews des
  4 états. Aucune logique de parcours d'arbre dans la vue.
- **Lecture Chrome (palier 1 — généralisation « source »)** : modèle Core
  `BookmarkSourceID` (browser + profil, identité stable) et `BookmarkSource`
  (id + nom d'affichage). `BookmarkReading` généralisé de `browser` à `source`, et
  Dashboard refondu **par source** (`SourceState`) au lieu de par navigateur — Safari
  inchangé (source mono-profil). Prépare les profils Chrome multiples. Tests adaptés,
  comportement identique.

### Modifié
- Passage du projet en **Swift 6** (`SWIFT_VERSION = 6.0`) avec concurrence stricte
  (`SWIFT_STRICT_CONCURRENCY = complete`) sur toutes les cibles.
- Réorganisation des fichiers template dans l'arborescence définitive :
  `BookmarkBridgeApp.swift` → `App/`, et `ContentView.swift` renommé en
  `DashboardView.swift` → `Features/Dashboard/`.

### Sécurité / Retiré
- `xcuserdata` (état utilisateur Xcode) retiré du suivi Git et ignoré désormais.

---

> Aucune version n'a encore été publiée. La première entrée versionnée sera ajoutée
> lors du premier jalon fonctionnel (voir la feuille de route dans `Docs/`).
