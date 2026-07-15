# ADR-0002 — Lecture seule avant toute écriture

- Statut : Accepté
- Date : 2026-07-15

## Contexte

BookmarkBridge manipule les favoris des navigateurs de l'utilisateur — des données
personnelles précieuses et non triviales à reconstituer. Une écriture erronée pourrait
corrompre ou effacer des favoris. La confiance de l'utilisateur est la priorité absolue.

## Décision

Nous imposons le principe **« lecture seule avant toute écriture »** :

1. Aucune écriture n'est implémentée tant que la chaîne lecture → modélisation →
   prévisualisation (dry-run) n'est pas éprouvée et testée.
2. Toute écriture est précédée d'une **sauvegarde horodatée** restaurable.
3. Le **dry-run** est le mode par défaut ; l'écriture réelle exige un consentement
   explicite après prévisualisation.
4. Les écritures sont **idempotentes et réversibles**.
5. L'accès fichier reste en **lecture seule** au niveau du projet
   (`ENABLE_USER_SELECTED_FILES = readonly`) tant que la phase d'écriture n'est pas ouverte.

Architecturalement, la capacité d'écriture (`BookmarkWriting`) n'existe pas dans le
graphe de dépendances de la phase 1 ; elle n'est introduite qu'en phase 2.

## Conséquences

- La première version utile est un outil de **lecture et de comparaison** sans risque.
- Le protocole `BookmarkWriting` et la couche `Backup` sont conçus et testés avant
  toute activation de l'écriture.
- Toute PR introduisant une écriture doit démontrer le respect de ces règles (voir
  `CONTRIBUTING.md`).
