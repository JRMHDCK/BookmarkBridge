# TODO — V2 (post-V1)

Idées et évolutions **reportées après la V1**. Rien ici n'est implémenté tant que
la V1 n'est pas stabilisée. Voir la politique de stabilisation V1 (correction de
bugs uniquement).

## Synchronisation
- **Écriture Safari** (`Bookmarks.plist`) — non implémentée en V1.
- **Synchronisation bidirectionnelle réelle** (Chrome → Safari en plus de Safari → Chrome). La V1 n'applique que le sens **Safari → Chrome**.
- **Profils Chrome connectés / `AccountBookmarks`** : mécanisme d'écriture fiable des favoris de compte (V1 = lecture seule sur `AccountBookmarks`).
- **Profils « deux stockages »** (`Bookmarks` + `AccountBookmarks`) : définir une stratégie fondée sur le comportement réel de Chrome (V1 = lecture seule + avertissement).
- **Déduplication intra-navigateur** : retirer les doublons déjà présents dans un même navigateur.
- **Placement des ajouts** : reconstruire l'arborescence de dossiers d'origine (via `SyncChange.sourcePath`) au lieu d'ajouter à la racine « Autres favoris ».
- **Sélecteur de paire de profils** pour la synchro (V1 = Safari ↔ premier profil Chrome).

## Finitions UI (déjà notées)
- Cartes de statistiques plus compactes façon « widget » ; bouton principal plus premium (voir notes de finition v1.4).

## Publication
- Passer `MARKETING_VERSION` à la version de release (dans les réglages Xcode) au moment du tag.

---
*Ajouter ici toute amélioration non indispensable rencontrée pendant la stabilisation, plutôt que de l'implémenter.*
