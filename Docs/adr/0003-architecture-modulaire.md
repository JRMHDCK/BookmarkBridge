# ADR-0003 — Architecture modulaire App / Core / Features / Shared

- Statut : Accepté
- Date : 2026-07-15

## Contexte

Une organisation « une couche = un dossier » (Models/ViewModels/Views/Services) devient
vite difficile à naviguer à mesure que les fonctionnalités s'ajoutent, et elle ne
protège pas le cœur métier des dépendances UI.

## Décision

Nous adoptons une séparation modulaire en quatre zones sous la cible applicative :

- **App** — point d'entrée `@main`, composition root, injection des dépendances.
- **Core** — domaine et logique métier, **sans dépendance à SwiftUI** (`Models`,
  `Services`, `Parsers`, `Security`, `Utilities`).
- **Features** — modules d'interface verticaux (`Dashboard`, `Synchronisation`,
  `Settings`, `Logs`), chacun avec ses `View` et `ViewModel`.
- **Shared** — composants, extensions et ressources UI transverses.

Règles de dépendances : `Core` ne dépend de rien d'autre ; `Features` peut dépendre de
`Core` et `Shared` mais pas d'une autre feature ; `Shared` ne contient aucun état
d'application. Voir `Docs/ARCHITECTURE.md`.

## Conséquences

- Le métier (`Core`) est testable en isolation, indépendamment de l'UI.
- Les features évoluent de façon autonome, sans couplage croisé.
- La frontière lecture/écriture (ADR-0002) se matérialise naturellement dans `Core/Services`.
- Léger surcoût d'organisation initiale (arborescence plus profonde).
