# BookmarkBridge DMG Builder

Ce module produit un DMG Release non signé, prêt à être publié sur GitHub
ou sur le site officiel. Il utilise exclusivement les outils fournis avec
macOS et Xcode.

## Générer le DMG

Depuis la racine du dépôt :

```sh
Distribution/DMG/Scripts/build-dmg.sh
```

Le script :

1. régénère le fond depuis l’icône officielle du catalogue d’assets ;
2. crée une archive Release non signée avec `xcodebuild` ;
3. copie `BookmarkBridge.app` et crée le lien vers `/Applications` ;
4. configure automatiquement la fenêtre Finder ;
5. compresse et vérifie le DMG final.

Le résultat est placé dans `Distribution/DMG/Output/` et porte la version
et le numéro de build de l’application. Ce répertoire n’est pas versionné.

Pour écrire le résultat dans un autre répertoire :

```sh
DMG_OUTPUT_DIRECTORY=/chemin/de/sortie \
    Distribution/DMG/Scripts/build-dmg.sh
```

## Modifier le fond

Le fond est généré par
`Scripts/generate-background.swift` dans
`Background/BookmarkBridge-DMG-Background.png`.

Le générateur charge directement l’icône officielle
`AppIcon-512@2x.png`. Il ne la recadre pas, ne la recolore pas et ne
modifie pas ses effets. Pour faire évoluer le décor, modifier uniquement
les couleurs, formes et textes dessinés autour du logo dans le
générateur, puis relancer le script principal.

La taille du fond (`660 × 420`) doit rester cohérente avec les dimensions
de la fenêtre Finder définies dans le modèle AppleScript.

## Modifier la disposition

La présentation Finder se trouve dans
`Templates/DMGLayout.applescript`.

Les principaux réglages sont :

- `bounds` : position et taille de la fenêtre ;
- `icon size` et `text size` : taille des éléments ;
- la position de `BookmarkBridge.app` ;
- la position du lien `Applications`.

Après toute modification, relancer le script principal. Aucune
intervention manuelle dans Finder n’est nécessaire.

## Pré-requis et limites

- macOS avec Xcode installé ;
- une session graphique Finder pour appliquer la présentation ;
- aucune signature ni notarisation n’est effectuée ;
- aucun outil tiers n’est nécessaire.
