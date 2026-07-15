# Contribuer à BookmarkBridge

Merci de contribuer ! Ce document résume le **processus**. Les **règles d'ingénierie**
(architecture, SOLID, conventions Swift 6, qualité) font autorité dans
[`CLAUDE.md`](CLAUDE.md) — à lire avant toute contribution.

## Prérequis

| Outil | Version |
|-------|---------|
| macOS | 26.5+ |
| Xcode | dernière version stable |
| Swift | 6 (concurrence stricte) |

## Principe non négociable — « Lecture seule avant toute écriture »

Aucune contribution ne doit introduire d'écriture dans les favoris d'un navigateur
tant que la chaîne lecture → modélisation → **prévisualisation (dry-run)** n'est pas
éprouvée et testée. Toute PR touchant à l'écriture doit démontrer explicitement le
respect des six règles de la section 3 de [`CLAUDE.md`](CLAUDE.md).

## Flux de travail

1. **Créer une branche** depuis `main` :
   - `feature/<description>` — nouvelle fonctionnalité
   - `fix/<description>` — correction
   - `chore/<description>` — maintenance, outillage, docs
2. **Développer** en respectant l'architecture (`App / Core / Features / Shared`, voir
   [`Docs/ARCHITECTURE.md`](Docs/ARCHITECTURE.md)) et les conventions Swift 6.
3. **Tester** : `⌘U` ou `xcodebuild test`. Toute correction de bug s'accompagne d'un
   test de non-régression. Aucun test ne touche aux favoris réels du système
   (utiliser des fixtures et des dossiers temporaires).
4. **Vérifier** : le projet compile sans avertissement (« zero-warning policy »).
5. **Ouvrir une PR** : une PR = une intention, avec description claire (quoi / pourquoi
   / comment tester).

## Commits — Conventional Commits

Format : `type(scope): sujet impératif court` (≤ 72 caractères).

Types : `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `build`, `ci`.

```
feat(reading): add Safari bookmark plist reader
test(diffing): cover folder rename detection
docs(architecture): document dependency rules
```

## Checklist avant de soumettre une PR

- [ ] La branche part de `main` et suit la convention de nommage.
- [ ] Le code respecte l'architecture et les conventions de [`CLAUDE.md`](CLAUDE.md).
- [ ] `Core` ne dépend ni de SwiftUI, ni de `Features`, ni de `Shared`.
- [ ] Build vert, **aucun avertissement** du compilateur.
- [ ] Tests ajoutés/à jour et verts ; aucun accès aux favoris réels.
- [ ] Aucune écriture dans les favoris sans les garde-fous de la section 3.
- [ ] `CHANGELOG.md` mis à jour (section « Non publié ») si pertinent.
- [ ] Commits atomiques au format Conventional Commits.

## Décisions d'architecture

Toute décision structurante est consignée sous forme d'ADR dans
[`Docs/adr/`](Docs/adr/). Proposer une nouvelle ADR pour toute évolution
architecturale significative.
