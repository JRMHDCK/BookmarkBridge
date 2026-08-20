# BookmarkBridge 0.9.4 bêta

## Nouveau workflow Chrome → Safari

- BookmarkBridge prépare un fichier HTML que Safari importe lui-même.
- Le fichier contient uniquement les nouveaux favoris importables détectés
  dans l’aperçu, afin d’éviter les doublons.
- L’application affiche le fichier dans le Finder et guide l’utilisateur dans
  le menu d’import de Safari.

## Sécurité et fiabilité

- Suppression complète de l’ancien writer qui modifiait directement
  `Bookmarks.plist`.
- Le sens Safari → Chrome conserve son écriture transactionnelle avec
  sauvegarde et restauration en cas d’échec.
- Le journal de diagnostic trace les étapes de préparation de l’import et
  l’identité du fichier Safari lu (taille, date, hash et inode).
- Les suppressions, déplacements, renommages et changements d’URL ne sont pas
  appliqués par l’import additif Safari ; ils sont signalés avant l’action.

## Compatibilité

- macOS 26.5 ou version ultérieure.
- Cette bêta n’est pas encore signée ni notariée par Apple.
