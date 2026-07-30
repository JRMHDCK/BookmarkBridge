# BookmarkBridge GitHub Release Kit

Ce module rassemble automatiquement tous les fichiers nécessaires à une
GitHub Release de BookmarkBridge. Le dossier généré est prêt à être téléversé
sans renommage ni préparation supplémentaire.

## Préparer une nouvelle Release

Depuis la racine du dépôt :

```sh
Distribution/GitHub/Scripts/build-release.sh
```

Le DMG correspondant à la version et au build du projet doit déjà exister.
Pour le produire :

```sh
Distribution/DMG/Scripts/build-dmg.sh
```

Le script GitHub :

1. lit la version, le build et la cible macOS dans le projet Xcode ;
2. retrouve automatiquement le DMG correspondant ;
3. déduit le libellé de Release depuis les notes officielles ;
4. calcule la taille et la somme SHA-256 du DMG ;
5. génère les notes de version et le changelog ;
6. copie le DMG et le manuel utilisateur ;
7. vérifie la présence et l’intégrité de chaque asset.

Le résultat est créé dans :

```text
Distribution/GitHub/Release/BookmarkBridge-<version>/
```

Ce répertoire est ignoré par Git. Pour choisir un autre emplacement :

```sh
GITHUB_RELEASE_DIRECTORY=/chemin/de/sortie \
    Distribution/GitHub/Scripts/build-release.sh
```

## Fichiers produits

Chaque dossier de Release contient exactement :

- le DMG versionné ;
- `SHA256.txt` ;
- `RELEASE_NOTES.md` ;
- `CHANGELOG.md` ;
- `BookmarkBridge-User-Guide.pdf`.

Les notes incluent automatiquement la version, le build, la date, la
configuration minimale, les limitations connues, le SHA-256 et la taille du
DMG.

## Mettre à jour le contenu éditorial

Les contenus réutilisables se trouvent dans `Templates/` :

- `RELEASE_NOTES.md.template` pour la présentation de la version ;
- `CHANGELOG.md.template` pour l’historique Git.

Les limitations sont injectées depuis `Documentation/KNOWN_ISSUES.md`. Elles
ne doivent contenir que des limitations confirmées.

Lorsqu’une version introduit de réels changements produit, mettre à jour les
paragraphes « Nouveautés » et « Améliorations » du modèle avant de générer le
kit.

## Publier sur GitHub

1. Ouvrir la page **Releases** du dépôt GitHub.
2. Choisir **Draft a new release**.
3. Sélectionner ou créer le tag prévu par le responsable de publication.
4. Utiliser le titre `BookmarkBridge <version>`.
5. Copier le contenu de `RELEASE_NOTES.md` dans la description.
6. Téléverser les cinq fichiers du dossier Release.
7. Vérifier le statut prerelease si la version est une bêta.
8. Publier uniquement après validation finale du Product Owner.

Le script ne crée aucun tag, ne pousse aucun commit et ne publie rien sur
GitHub.
