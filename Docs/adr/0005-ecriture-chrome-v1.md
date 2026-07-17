# ADR-0005 — Écriture Chrome additive et réversible en V1

- Statut : Accepté
- Date : 2026-07-17

## Contexte

L'ADR-0002 a interdit toute écriture tant que la lecture réelle, la modélisation,
le diff et l'aperçu n'étaient pas éprouvés. Ces préconditions sont désormais
couvertes par les tests et validées manuellement. Une V1 utile doit pouvoir appliquer
les favoris Safari absents dans un profil Chrome local sans mettre en danger les
données existantes.

Chrome stocke ses favoris locaux dans un fichier JSON `Bookmarks`, accompagné d'un
checksum et, conventionnellement, d'un fichier `Bookmarks.bak`. Le sandbox macOS
impose que toute la transaction s'exécute dans un security scope explicitement
autorisé.

## Décision

La V1 ouvre une capacité d'écriture strictement limitée à Safari → fichier Chrome
local `Bookmarks`.

Cette capacité respecte les invariants suivants :

1. aperçu et consentement explicite avant application ;
2. refus lorsque Chrome est ouvert ;
3. security scope lecture-écriture valide pendant toute la transaction ;
4. sauvegarde horodatée persistante obligatoire avant toute modification ;
5. relecture du fichier courant et filtrage idempotent des favoris déjà présents ;
6. génération d'un checksum compatible Chrome ;
7. création ou remplacement atomique de `Bookmarks.bak` ;
8. seconde vérification de Chrome avant remplacement atomique de `Bookmarks` ;
9. conservation du handle si la transaction échoue après la sauvegarde ;
10. restauration soumise aux mêmes contrôles de fermeture de Chrome et de scope.

La V1 n'écrit ni dans Safari, ni dans `AccountBookmarks`. Un profil Chrome ambigu ou
uniquement fondé sur `AccountBookmarks` reste en lecture seule.

## Conséquences

- L'entitlement devient `com.apple.security.files.user-selected.read-write` tout en
  conservant l'App Sandbox.
- L'écriture est additive : aucune suppression, aucun déplacement et aucun renommage.
- Une seconde application du même plan n'ajoute aucun doublon.
- Les sauvegardes sont retrouvées par URL de profil exacte et restent restaurables
  après réouverture de l'interface ou redémarrage de l'application.
- L'écriture Safari et la synchronisation bidirectionnelle réelle restent différées.
