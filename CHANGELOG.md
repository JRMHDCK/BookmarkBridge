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
