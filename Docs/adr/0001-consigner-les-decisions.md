# ADR-0001 — Consigner les décisions d'architecture

- Statut : Accepté
- Date : 2026-07-15

## Contexte

BookmarkBridge vise une base de code maintenable sur la durée. Les décisions
structurantes (architecture, sécurité, dépendances) doivent être traçables et
compréhensibles par tout contributeur, y compris futur.

## Décision

Nous adoptons les **Architecture Decision Records (ADR)**, stockés dans `Docs/adr/`,
numérotés séquentiellement et immuables une fois acceptés. Toute évolution
architecturale significative fait l'objet d'un nouvel ADR.

## Conséquences

- L'historique des choix est explicite et versionné avec le code.
- Un ADR obsolète n'est pas supprimé : il est marqué « Remplacé par ADR-YYYY ».
- Coût léger de documentation à chaque décision structurante.
