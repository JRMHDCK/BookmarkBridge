# Journal des décisions d'architecture (ADR)

Ce dossier consigne les **Architecture Decision Records** : chaque décision
structurante est documentée dans un fichier numéroté et immuable.

- Format inspiré de [Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions).
- Un ADR n'est jamais modifié une fois « Accepté » ; on le remplace par un nouvel ADR
  qui le supersède (statut « Remplacé par ADR-XXXX »).

## Index

| N°   | Titre                                   | Statut   |
|------|-----------------------------------------|----------|
| 0001 | Consigner les décisions d'architecture  | Accepté  |
| 0002 | Lecture seule avant toute écriture      | Accepté  |
| 0003 | Architecture modulaire App/Core/Features/Shared | Accepté |

## Modèle

```
# ADR-XXXX — Titre

- Statut : Proposé | Accepté | Remplacé par ADR-YYYY
- Date : AAAA-MM-JJ

## Contexte
## Décision
## Conséquences
```
