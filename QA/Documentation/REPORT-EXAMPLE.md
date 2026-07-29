# BookmarkBridge QA Report

- Date : `2026-07-29T10:00:00+02:00`
- Version : `1.0` (build `1`)
- Commit : `0123456789abcdef0123456789abcdef01234567`
- Branche : `feat/ui-integration`
- Scénarios : `15`
- Succès : `15`
- Échecs : `0`
- Temps total : `180.000 s`

## Datasets

| Dataset | Favoris Safari | Favoris Chrome | Dossiers/navigateur | Round-trip |
|---|---:|---:|---:|---|
| Small | 50 | 50 | 8 | OK |
| Medium | 500 | 500 | 30 | OK |
| Large | 2000 | 2000 | 80 | OK |
| Extreme | 7500 | 7500 | 250 | OK |
| Pathological | 1500 | 1500 | 120 | OK |

## Scénarios

| Scénario | Dataset | Statut | Durée |
|---|---|---|---:|
| `first-synchronization` | Small | OK | 0.010 s |
| `pathological-formats` | Pathological | OK | 0.100 s |

## Validations

| Validation | Statut | Durée | Journal |
|---|---|---:|---|
| build-debug | PASSED | 20.000 s | `build-debug.log` |
| build-release | PASSED | 25.000 s | `build-release.log` |
| unit-tests | PASSED | 90.000 s | `unit-tests.log` |
| ui-tests | PASSED | 40.000 s | `ui-tests.log` |

## Écarts

Aucun écart détecté.
