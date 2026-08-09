# Limitations connues

Ce document recense uniquement les limitations confirmées de BookmarkBridge
0.9.2 Beta.

## Sources en lecture seule

- Chrome `AccountBookmarks` n'est jamais modifié.
- Un profil Chrome dont `Bookmarks` et `AccountBookmarks` contiennent tous deux
  des données reste en lecture seule afin d'éviter de choisir arbitrairement une
  source d'autorité.

## Navigateurs et exécution

- Le navigateur cible doit être fermé pendant une synchronisation ou une restauration.
- Seuls Safari et Google Chrome sont pris en charge.
- Il n'existe pas de synchronisation cloud, multi-machine, temps réel ou en
  arrière-plan.
- La bêta n’est pas encore signée ni notariée par Apple.

## Compatibilité système

BookmarkBridge 0.9.2 Beta nécessite macOS 26.5 ou une version ultérieure.
