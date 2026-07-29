# Limitations connues

Ce document recense uniquement les limitations confirmées de BookmarkBridge
0.9.0-beta1.

## Sens de synchronisation

La bêta applique uniquement les ajouts de Safari vers un fichier `Bookmarks`
Chrome local. Le sens Chrome vers Safari peut être prévisualisé par le moteur,
mais n'est pas appliqué.

## Sources en lecture seule

- Safari n'est jamais modifié.
- Chrome `AccountBookmarks` n'est jamais modifié.
- Un profil Chrome dont `Bookmarks` et `AccountBookmarks` contiennent tous deux
  des données reste en lecture seule afin d'éviter de choisir arbitrairement une
  source d'autorité.

## Structure des dossiers

Les favoris ajoutés à Chrome sont placés dans « Autres favoris ». Leur
arborescence Safari d'origine n'est pas reconstruite dans cette version.

## Navigateurs et exécution

- Chrome doit être fermé pendant une synchronisation ou une restauration.
- Seuls Safari et Google Chrome sont pris en charge.
- Il n'existe pas de synchronisation cloud, multi-machine, temps réel ou en
  arrière-plan.

## Compatibilité système

BookmarkBridge 0.9.0-beta1 nécessite macOS 26.5 ou une version ultérieure.
