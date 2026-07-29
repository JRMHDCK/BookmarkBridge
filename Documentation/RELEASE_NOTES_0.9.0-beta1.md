# BookmarkBridge 0.9.0-beta1

- Date de préparation : 29 juillet 2026
- Version : 0.9.0 (build 1)
- Moteur de synchronisation : BSE v1.0

## Résumé

BookmarkBridge est une application macOS native qui compare les favoris Safari
et Google Chrome, présente les changements avant application et réalise une
synchronisation additive Safari vers Chrome. Cette version constitue la première
bêta destinée à un usage quotidien.

La protection des données reste prioritaire : l'application exige une action
explicite, refuse d'écrire pendant l'exécution de Chrome, crée une sauvegarde
restaurable et remplace le fichier Chrome de manière atomique.

## Principales fonctionnalités

- lecture des favoris Safari et des profils Chrome autorisés par l'utilisateur ;
- App Sandbox et autorisations persistantes par security-scoped bookmarks ;
- dashboard avec état des sources et statistiques ;
- exploration hiérarchique, fil d'Ariane et recherche multi-sources ;
- aperçu des différences avant toute synchronisation ;
- synchronisation additive Safari vers un profil Chrome local sélectionné ;
- normalisation des URL et filtrage idempotent des doublons à ajouter ;
- sauvegarde horodatée, `Bookmarks.bak`, remplacement atomique et restauration ;
- refus des écritures lorsque Chrome est ouvert ;
- interface SwiftUI native macOS et plateforme QA automatisée.

## Limitations connues

- la synchronisation appliquée est uniquement Safari vers Chrome ;
- Safari reste en lecture seule ;
- les fichiers Chrome `AccountBookmarks` restent en lecture seule ;
- un profil possédant simultanément des stockages local et compte non vides est
  présenté en lecture seule ;
- les favoris ajoutés sont placés dans « Autres favoris » sans reconstruire
  l'arborescence Safari ;
- Firefox, Edge et les autres navigateurs ne sont pas pris en charge ;
- aucune synchronisation cloud, multi-machine ou en arrière-plan.

Voir également [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

## Prérequis

- macOS 26.5 ou version ultérieure ;
- Mac Apple Silicon ou Intel 64 bits ;
- Safari et Google Chrome installés pour utiliser les sources correspondantes ;
- autorisation explicite du fichier Safari et du dossier Chrome demandée par
  l'application ;
- Chrome fermé pendant une synchronisation ou une restauration.

## Compatibilité

L'application est distribuable sous forme de binaire universel `arm64` et
`x86_64`. Elle lit le fichier Safari `Bookmarks.plist` et les fichiers Chrome
locaux `Bookmarks`. Les profils utilisant `AccountBookmarks` peuvent être lus,
mais ne sont jamais modifiés dans cette bêta.

Les données sont traitées localement. Aucun service réseau ou compte cloud
BookmarkBridge n'est nécessaire.

## Évolution depuis les premières versions de développement

- remplacement du prototype en mémoire par des lecteurs Safari et Chrome réels
  derrière des abstractions testables ;
- adoption de Swift 6, de la concurrence stricte et de l'architecture
  App/Core/Features/Shared ;
- construction du BSE v1.0 pour l'identité, le matching, le diff, la
  planification, l'exécution et la restauration ;
- ajout de la transaction Chrome sauvegardée, idempotente et atomique ;
- intégration complète du workflow de synchronisation dans l'interface native ;
- refonte visuelle macOS, navigation, recherche et explorateur hiérarchique ;
- ajout d'une plateforme QA avec cinq familles de datasets et quinze scénarios ;
- audit final du projet Xcode, des ressources et des réglages Release.
