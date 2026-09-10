const SUPPORTED_LANGUAGES = ['fr', 'en', 'es', 'de'];
const LANGUAGE_STORAGE_KEY = 'bookmarkbridge-language';
const MANUAL_PDF_BY_LANGUAGE = Object.freeze({
  fr: '/downloads/BookmarkBridge-User-Guide-fr.pdf',
  en: '/downloads/BookmarkBridge-User-Guide-en.pdf',
  es: '/downloads/BookmarkBridge-User-Guide-es.pdf',
  de: '/downloads/BookmarkBridge-User-Guide-de.pdf'
});
const GATEKEEPER_IMAGE_BY_LANGUAGE = Object.freeze({
  fr: Object.freeze({
    1: '/assets/images/gatekeeper/step-1-blocked-fr.png?v=20260809-2',
    2: '/assets/images/gatekeeper/step-2-settings-fr.png?v=20260809-2',
    3: '/assets/images/gatekeeper/step-3-confirm-fr.png?v=20260809-2'
  }),
  en: Object.freeze({
    1: '/assets/images/gatekeeper/step-1-blocked-en.png?v=20260809-2',
    2: '/assets/images/gatekeeper/step-2-settings-en.png?v=20260809-2',
    3: '/assets/images/gatekeeper/step-3-confirm-en.png?v=20260809-2'
  }),
  es: Object.freeze({
    1: '/assets/images/gatekeeper/step-1-blocked-es.png?v=20260809-2',
    2: '/assets/images/gatekeeper/step-2-settings-es.png?v=20260809-2',
    3: '/assets/images/gatekeeper/step-3-confirm-es.png?v=20260809-2'
  }),
  de: Object.freeze({
    1: '/assets/images/gatekeeper/step-1-blocked-de.png?v=20260809-2',
    2: '/assets/images/gatekeeper/step-2-settings-de.png?v=20260809-2',
    3: '/assets/images/gatekeeper/step-3-confirm-de.png?v=20260809-2'
  })
});

const translations = {
  en: {
    'BookmarkBridge — Synchronisez Safari et Chrome sur macOS': 'BookmarkBridge — Sync Safari and Chrome on macOS',
    'BookmarkBridge synchronise vos favoris Safari et Chrome tout en préservant leur organisation, directement sur votre Mac et sans cloud.': 'BookmarkBridge syncs your Safari and Chrome bookmarks while preserving their organization, directly on your Mac and without the cloud.',
    'Synchronisez vos favoris Safari et Chrome directement sur votre Mac, dans les deux sens et sans cloud.': 'Sync your Safari and Chrome bookmarks directly on your Mac, both ways and without the cloud.',
    'Télécharger BookmarkBridge pour macOS': 'Download BookmarkBridge for macOS',
    'Téléchargez BookmarkBridge 0.9.3 pour macOS et suivez le guide illustré pour autoriser sa première ouverture avec Gatekeeper.': 'Download BookmarkBridge 0.9.3 for macOS and follow the illustrated guide to allow its first launch with Gatekeeper.',
    'Téléchargez BookmarkBridge et suivez les trois étapes pour autoriser sa première ouverture sur macOS.': 'Download BookmarkBridge and follow the three steps to allow its first launch on macOS.',
    'fr_FR': 'en_US',
    'Icône de BookmarkBridge': 'BookmarkBridge icon',
    'Aller au contenu': 'Skip to content',
    'BookmarkBridge — Accueil': 'BookmarkBridge — Home',
    'Ouvrir le menu': 'Open menu',
    'Fermer le menu': 'Close menu',
    'Navigation principale': 'Main navigation',
    'Langue du site': 'Site language',
    'Fonctionnalités': 'Features',
    'Confidentialité': 'Privacy',
    'Fonctionnement': 'How it works',
    'Télécharger': 'Download',
    'Safari et Chrome.': 'Safari and Chrome.',
    'Enfin synchronisés.': 'Finally in sync.',
    'Tester gratuitement': 'Try for free',
    'Découvrir BookmarkBridge': 'Discover BookmarkBridge',
    'Bêta gratuite 0.9.3 (build 1) · macOS 26.5 minimum.': 'Free beta 0.9.3 (build 1) · macOS 26.5 or later.',
    'Safari et Chrome reliés par BookmarkBridge': 'Safari and Chrome connected by BookmarkBridge',
    'Aperçu prêt': 'Preview ready',
    'Ajouts, suppressions, déplacements et modifications visibles avant application.': 'See additions, deletions, moves, and edits before applying them.',
    'Principes de BookmarkBridge': 'BookmarkBridge principles',
    'Traitement local': 'Local processing',
    'Sans compte': 'No account',
    'Sans extension': 'No extension',
    'Sans publicité ni tracking': 'No ads or tracking',
    'Les preuves essentielles': 'The essentials at a glance',
    'navigateurs synchronisés': 'browsers synchronized',
    'structure des dossiers conservée': 'folder structure preserved',
    'donnée envoyée sur Internet': 'data sent over the Internet',
    'aperçu avant modification': 'preview before changes',
    'fonctionnement sans compte ni cloud': 'works without an account or cloud',
    'Tout est à sa place': 'Everything stays in place',
    'Une synchronisation claire, jusque dans les détails.': 'Clear synchronization, down to the details.',
    'BookmarkBridge rend une opération complexe lisible et maîtrisable, même sans connaissances techniques.': 'BookmarkBridge makes a complex operation clear and manageable, even without technical knowledge.',
    'Safari et Chrome en un clic': 'Safari and Chrome in one click',
    'Lancez la synchronisation depuis une interface unique, sans extension ni plugin à installer.': 'Start synchronization from one interface, with no extension or plug-in to install.',
    'Organisation préservée': 'Organization preserved',
    'Dossiers, sous-dossiers, structure et ordre restent fidèles à votre bibliothèque.': 'Folders, subfolders, structure, and order remain faithful to your library.',
    'Aperçu avant application': 'Preview before applying',
    'Examinez les ajouts, suppressions, déplacements et modifications avant d’agir.': 'Review additions, deletions, moves, and edits before taking action.',
    'Vraiment natif sur Mac': 'Truly native on Mac',
    'Développé en Swift et SwiftUI pour une expérience familière, fluide et intégrée à macOS.': 'Built with Swift and SwiftUI for a familiar, smooth experience integrated with macOS.',
    'Détection intelligente': 'Smart detection',
    'Les doublons, erreurs et conflits sont repérés pour vous aider à comprendre les changements.': 'Duplicates, errors, and conflicts are identified to help you understand the changes.',
    'Prêt pour vos bibliothèques': 'Ready for your libraries',
    'Des performances pensées pour les grandes collections, dans une interface accessible aux utilisateurs non techniques.': 'Performance designed for large collections, in an interface accessible to non-technical users.',
    'Privé par conception': 'Private by design',
    'Tout se passe sur votre Mac.': 'Everything happens on your Mac.',
    'BookmarkBridge traite vos favoris localement. Aucun serveur intermédiaire, aucun compte et aucun mécanisme publicitaire ne sont nécessaires.': 'BookmarkBridge processes your bookmarks locally. No intermediary server, account, or advertising system is required.',
    'Aucune donnée de favoris n’est envoyée sur Internet.': 'No bookmark data is sent over the Internet.',
    'Sans compte, publicité ou tracking': 'No account, ads, or tracking',
    'Pas d’inscription, de profilage ni de suivi publicitaire.': 'No registration, profiling, or ad tracking.',
    'Permissions officielles macOS': 'Official macOS permissions',
    'Les accès sont demandés clairement avec les mécanismes prévus par macOS, sans accès caché.': 'Access is requested clearly through the mechanisms provided by macOS, with no hidden access.',
    'Vous gardez la main': 'You stay in control',
    'L’aperçu vous permet de comprendre les changements avant leur application.': 'The preview lets you understand changes before they are applied.',
    'Simple dès le premier lancement': 'Simple from the first launch',
    'De vos navigateurs à une vue claire.': 'From your browsers to one clear view.',
    'Autorisez les dossiers': 'Allow folder access',
    'macOS vous demande explicitement l’accès nécessaire aux favoris de Safari et Chrome.': 'macOS explicitly asks you for the access needed to reach Safari and Chrome bookmarks.',
    'Consultez l’aperçu': 'Review the preview',
    'BookmarkBridge présente les différences et signale les doublons, erreurs ou conflits détectés.': 'BookmarkBridge shows the differences and flags any detected duplicates, errors, or conflicts.',
    'Synchronisez en un clic': 'Sync in one click',
    'Vous déclenchez l’opération lorsque l’organisation proposée vous convient.': 'You start the operation when you are happy with the proposed organization.',
    'Questions fréquentes': 'Frequently asked questions',
    'L’essentiel, sans jargon.': 'The essentials, without the jargon.',
    'Mes favoris sont-ils envoyés sur Internet ?': 'Are my bookmarks sent over the Internet?',
    'Non. BookmarkBridge fonctionne localement sur votre Mac, sans cloud ni serveur pour traiter vos favoris.': 'No. BookmarkBridge works locally on your Mac, without a cloud or server processing your bookmarks.',
    'Mes dossiers et leur ordre sont-ils conservés ?': 'Are my folders and their order preserved?',
    'BookmarkBridge est conçu pour préserver les dossiers, sous-dossiers, leur structure et l’ordre des favoris.': 'BookmarkBridge is designed to preserve folders, subfolders, their structure, and bookmark order.',
    'Faut-il installer une extension dans Safari ou Chrome ?': 'Do I need to install an extension in Safari or Chrome?',
    'Non. BookmarkBridge est une application macOS autonome : aucune extension ni aucun plugin de navigateur ne sont nécessaires.': 'No. BookmarkBridge is a standalone macOS app: no browser extension or plug-in is required.',
    'Comment BookmarkBridge accède-t-il aux favoris ?': 'How does BookmarkBridge access bookmarks?',
    'Uniquement après votre autorisation explicite, via les permissions officielles proposées par macOS.': 'Only after your explicit approval, through the official permissions provided by macOS.',
    'Quand l’application sera-t-elle disponible ?': 'When will the app be available?',
    'La bêta macOS est disponible gratuitement. Téléchargez le DMG depuis la': 'The macOS beta is available free of charge. Download the DMG from the',
    'page de téléchargement': 'download page',
    ', puis glissez BookmarkBridge dans Applications.': ', then drag BookmarkBridge into Applications.',
    'BookmarkBridge pour macOS': 'BookmarkBridge for macOS',
    'Découvrez BookmarkBridge gratuitement sur votre Mac.': 'Discover BookmarkBridge for free on your Mac.',
    'Documentation': 'Documentation',
    'Bêta gratuite pour macOS': 'Free beta for macOS',
    'La version bêta n’est pas encore notariée par Apple. Le message de sécurité affiché au premier lancement est donc attendu : les trois étapes ci-dessous vous guident sans désactiver les protections de votre Mac.': 'The beta has not yet been notarized by Apple. The security message shown on first launch is therefore expected: the three steps below guide you without disabling your Mac’s protections.',
    'Télécharger le DMG': 'Download the DMG',
    'Consulter le manuel PDF': 'View the PDF guide',
    'Version 0.9.3 (build 1) · macOS 26.5 minimum · environ 9,92 Mio.': 'Version 0.9.3 (build 1) · macOS 26.5 or later · about 9.92 MiB.',
    'Aperçu de BookmarkBridge dans une fenêtre macOS': 'Preview of BookmarkBridge in a macOS window',
    'Prêt à installer': 'Ready to install',
    'Une application macOS native, locale et sans extension.': 'A native, local macOS app with no extension.',
    'Première ouverture': 'First launch',
    'Trois étapes, une seule fois.': 'Three steps, just once.',
    'Installez BookmarkBridge puis autorisez sa première ouverture avec les réglages prévus par macOS. Ces écrans peuvent varier légèrement selon votre version du système.': 'Install BookmarkBridge, then allow its first launch using the settings provided by macOS. These screens may vary slightly depending on your system version.',
    'Télécharger et ouvrir BookmarkBridge': 'Download and open BookmarkBridge',
    'Téléchargez le DMG, ouvrez-le et glissez': 'Download the DMG, open it, and drag',
    'dans': 'into',
    'Applications': 'Applications',
    '. Lancez ensuite BookmarkBridge depuis ce dossier. macOS affiche le blocage ci-dessous : cliquez sur': '. Then launch BookmarkBridge from that folder. macOS displays the warning below: click',
    'Terminé': 'Done',
    'Message macOS indiquant que BookmarkBridge ne peut pas être ouvert, avec le bouton Terminé': 'macOS message stating that BookmarkBridge cannot be opened, with the Done button',
    'Le premier blocage est normal pour cette bêta non notariée.': 'The first warning is normal for this unnotarized beta.',
    'Autoriser dans Réglages Système': 'Allow in System Settings',
    'Ouvrez': 'Open',
    'Réglages Système': 'System Settings',
    ', puis': ', then',
    'Confidentialité et sécurité': 'Privacy & Security',
    '. Descendez jusqu’à la section Sécurité et cliquez sur': '. Scroll down to the Security section and click',
    'Ouvrir quand même': 'Open Anyway',
    'à côté du message concernant BookmarkBridge.': 'next to the message about BookmarkBridge.',
    'Réglages Système, rubrique Confidentialité et sécurité, avec le bouton Ouvrir quand même pour BookmarkBridge': 'System Settings, Privacy & Security, with the Open Anyway button for BookmarkBridge',
    'Le bouton n’apparaît qu’après une première tentative d’ouverture.': 'The button only appears after a first attempt to open the app.',
    'Cliquer sur « Ouvrir quand même »': 'Click “Open Anyway”',
    'Dans la dernière fenêtre de confirmation, cliquez sur': 'In the final confirmation window, click',
    '. macOS peut demander votre mot de passe ou Touch ID. BookmarkBridge s’ouvrira ensuite normalement.': '. macOS may ask for your password or Touch ID. BookmarkBridge will then open normally.',
    'Fenêtre de confirmation macOS avec le bouton Ouvrir quand même pour BookmarkBridge': 'macOS confirmation window with the Open Anyway button for BookmarkBridge',
    'Vérifiez toujours que le nom affiché est bien « BookmarkBridge ».': 'Always check that the displayed name is “BookmarkBridge”.',
    'Gardez les protections macOS actives.': 'Keep macOS protections enabled.',
    'Cette procédure autorise uniquement BookmarkBridge. Elle ne désactive ni Gatekeeper ni les contrôles de sécurité des autres applications.': 'This procedure allows only BookmarkBridge. It does not disable Gatekeeper or the security checks for other apps.',
    'Prêt à commencer ?': 'Ready to get started?',
    'Le DMG contient BookmarkBridge.app et un raccourci vers Applications.': 'The DMG contains BookmarkBridge.app and a shortcut to Applications.',
    'Télécharger BookmarkBridge': 'Download BookmarkBridge',
    'Somme SHA-256': 'SHA-256 checksum',
    'Manuel utilisateur PDF': 'PDF user guide',
    'BookmarkBridge compare vos favoris Safari et Chrome et utilise un workflow local adapté à chaque direction, sans cloud.': 'BookmarkBridge compares your Safari and Chrome bookmarks and uses a local workflow tailored to each direction, without the cloud.',
    'Safari vers Chrome est transactionnel ; Chrome vers Safari prépare un import additif piloté par Safari.': 'Safari to Chrome is transactional; Chrome to Safari prepares an additive import handled by Safari.',
    'Le moyen le plus simple d\'organiser et synchroniser vos favoris Mac entre Chrome et Safari.': 'The simplest way to organize and sync your Mac bookmarks between Chrome and Safari.',
    'Bêta gratuite 0.9.4 (build 2) · macOS 26.5 minimum.': 'Free beta 0.9.4 (build 2) · macOS 26.5 or later.',
    'Créations importables et opérations non prises en charge visibles avant action.': 'See importable additions and unsupported operations before taking action.',
    'workflows adaptés': 'tailored workflows',
    'écriture Safari directe évitée': 'no direct Safari write',
    'Deux directions, deux workflows sûrs': 'Two directions, two safe workflows',
    'Safari → Chrome se synchronise automatiquement. Chrome → Safari prépare automatiquement un fichier prêt à être importé dans Safari.': 'Safari → Chrome syncs automatically. Chrome → Safari automatically prepares a file ready to be imported into Safari.',
    'Organisation maîtrisée': 'Controlled organization',
    'Les nouveaux favoris importables conservent leur structure de dossiers ; les limites de l’import Safari sont signalées.': 'New importable bookmarks keep their folder structure; Safari import limitations are clearly reported.',
    'Examinez chaque différence avant d’agir, y compris les opérations qu’un import Safari additif ne peut pas appliquer.': 'Review every difference before taking action, including operations that an additive Safari import cannot apply.',
    'Suivez le workflow adapté': 'Follow the tailored workflow',
    'Safari → Chrome est appliqué après confirmation. Chrome → Safari ouvre Safari et le fichier HTML à importer.': 'Safari → Chrome is applied after confirmation. Chrome → Safari opens Safari and the HTML file to import.',
    'Safari → Chrome préserve la structure par écriture transactionnelle. Chrome → Safari conserve la structure des nouveaux favoris importés, mais l’import additif ne peut pas appliquer les suppressions, déplacements, renommages ou changements d’URL.': 'Safari → Chrome preserves structure through transactional writing. Chrome → Safari keeps the structure of newly imported bookmarks, but the additive import cannot apply deletions, moves, renames, or URL changes.',
    'Téléchargez BookmarkBridge 0.9.4 pour macOS et suivez le guide illustré pour autoriser sa première ouverture avec Gatekeeper.': 'Download BookmarkBridge 0.9.4 for macOS and follow the illustrated guide to allow its first launch with Gatekeeper.',
    'Version 0.9.4 (build 2) · macOS 26.5 minimum · environ 10,03 Mio.': 'Version 0.9.4 (build 2) · macOS 26.5 or later · about 10.03 MiB.',
    'Voir le workflow 0.9.4': 'View the 0.9.4 workflow',
    'Documentation 0.9.4': '0.9.4 documentation'
  },
  es: {
    'BookmarkBridge — Synchronisez Safari et Chrome sur macOS': 'BookmarkBridge — Sincroniza Safari y Chrome en macOS',
    'BookmarkBridge synchronise vos favoris Safari et Chrome tout en préservant leur organisation, directement sur votre Mac et sans cloud.': 'BookmarkBridge sincroniza tus marcadores de Safari y Chrome conservando su organización, directamente en tu Mac y sin nube.',
    'Synchronisez vos favoris Safari et Chrome directement sur votre Mac, dans les deux sens et sans cloud.': 'Sincroniza tus marcadores de Safari y Chrome directamente en tu Mac, en ambos sentidos y sin nube.',
    'Télécharger BookmarkBridge pour macOS': 'Descargar BookmarkBridge para macOS',
    'Téléchargez BookmarkBridge 0.9.3 pour macOS et suivez le guide illustré pour autoriser sa première ouverture avec Gatekeeper.': 'Descarga BookmarkBridge 0.9.3 para macOS y sigue la guía ilustrada para autorizar su primera apertura con Gatekeeper.',
    'Téléchargez BookmarkBridge et suivez les trois étapes pour autoriser sa première ouverture sur macOS.': 'Descarga BookmarkBridge y sigue los tres pasos para autorizar su primera apertura en macOS.',
    'fr_FR': 'es_ES',
    'Icône de BookmarkBridge': 'Icono de BookmarkBridge',
    'Aller au contenu': 'Ir al contenido',
    'BookmarkBridge — Accueil': 'BookmarkBridge — Inicio',
    'Ouvrir le menu': 'Abrir el menú',
    'Fermer le menu': 'Cerrar el menú',
    'Navigation principale': 'Navegación principal',
    'Langue du site': 'Idioma del sitio',
    'Fonctionnalités': 'Funciones',
    'Confidentialité': 'Privacidad',
    'Fonctionnement': 'Cómo funciona',
    'Télécharger': 'Descargar',
    'Safari et Chrome.': 'Safari y Chrome.',
    'Enfin synchronisés.': 'Por fin sincronizados.',
    'Tester gratuitement': 'Probar gratis',
    'Découvrir BookmarkBridge': 'Descubrir BookmarkBridge',
    'Bêta gratuite 0.9.3 (build 1) · macOS 26.5 minimum.': 'Beta gratuita 0.9.3 (build 1) · macOS 26.5 o posterior.',
    'Safari et Chrome reliés par BookmarkBridge': 'Safari y Chrome conectados por BookmarkBridge',
    'Aperçu prêt': 'Vista previa lista',
    'Ajouts, suppressions, déplacements et modifications visibles avant application.': 'Consulta las adiciones, eliminaciones, movimientos y cambios antes de aplicarlos.',
    'Principes de BookmarkBridge': 'Principios de BookmarkBridge',
    'Traitement local': 'Procesamiento local',
    'Sans compte': 'Sin cuenta',
    'Sans extension': 'Sin extensión',
    'Sans publicité ni tracking': 'Sin publicidad ni seguimiento',
    'Les preuves essentielles': 'Lo esencial de un vistazo',
    'navigateurs synchronisés': 'navegadores sincronizados',
    'structure des dossiers conservée': 'estructura de carpetas conservada',
    'donnée envoyée sur Internet': 'datos enviados por Internet',
    'aperçu avant modification': 'vista previa antes de modificar',
    'fonctionnement sans compte ni cloud': 'funciona sin cuenta ni nube',
    'Tout est à sa place': 'Todo permanece en su sitio',
    'Une synchronisation claire, jusque dans les détails.': 'Una sincronización clara hasta el último detalle.',
    'BookmarkBridge rend une opération complexe lisible et maîtrisable, même sans connaissances techniques.': 'BookmarkBridge convierte una operación compleja en algo claro y controlable, incluso sin conocimientos técnicos.',
    'Safari et Chrome en un clic': 'Safari y Chrome con un clic',
    'Lancez la synchronisation depuis une interface unique, sans extension ni plugin à installer.': 'Inicia la sincronización desde una única interfaz, sin extensiones ni complementos que instalar.',
    'Organisation préservée': 'Organización conservada',
    'Dossiers, sous-dossiers, structure et ordre restent fidèles à votre bibliothèque.': 'Las carpetas, subcarpetas, estructura y orden se mantienen fieles a tu biblioteca.',
    'Aperçu avant application': 'Vista previa antes de aplicar',
    'Examinez les ajouts, suppressions, déplacements et modifications avant d’agir.': 'Revisa las adiciones, eliminaciones, movimientos y cambios antes de actuar.',
    'Vraiment natif sur Mac': 'Realmente nativo en Mac',
    'Développé en Swift et SwiftUI pour une expérience familière, fluide et intégrée à macOS.': 'Desarrollado con Swift y SwiftUI para ofrecer una experiencia familiar, fluida e integrada en macOS.',
    'Détection intelligente': 'Detección inteligente',
    'Les doublons, erreurs et conflits sont repérés pour vous aider à comprendre les changements.': 'Se detectan duplicados, errores y conflictos para ayudarte a comprender los cambios.',
    'Prêt pour vos bibliothèques': 'Preparado para tus bibliotecas',
    'Des performances pensées pour les grandes collections, dans une interface accessible aux utilisateurs non techniques.': 'Rendimiento pensado para grandes colecciones, en una interfaz accesible para usuarios sin conocimientos técnicos.',
    'Privé par conception': 'Privado desde el diseño',
    'Tout se passe sur votre Mac.': 'Todo ocurre en tu Mac.',
    'BookmarkBridge traite vos favoris localement. Aucun serveur intermédiaire, aucun compte et aucun mécanisme publicitaire ne sont nécessaires.': 'BookmarkBridge procesa tus marcadores de forma local. No necesita servidores intermediarios, cuentas ni mecanismos publicitarios.',
    'Aucune donnée de favoris n’est envoyée sur Internet.': 'Ningún dato de tus marcadores se envía por Internet.',
    'Sans compte, publicité ou tracking': 'Sin cuenta, publicidad ni seguimiento',
    'Pas d’inscription, de profilage ni de suivi publicitaire.': 'Sin registro, creación de perfiles ni seguimiento publicitario.',
    'Permissions officielles macOS': 'Permisos oficiales de macOS',
    'Les accès sont demandés clairement avec les mécanismes prévus par macOS, sans accès caché.': 'El acceso se solicita claramente mediante los mecanismos de macOS, sin accesos ocultos.',
    'Vous gardez la main': 'Tú mantienes el control',
    'L’aperçu vous permet de comprendre les changements avant leur application.': 'La vista previa te permite comprender los cambios antes de aplicarlos.',
    'Simple dès le premier lancement': 'Sencillo desde el primer inicio',
    'De vos navigateurs à une vue claire.': 'De tus navegadores a una vista clara.',
    'Autorisez les dossiers': 'Autoriza las carpetas',
    'macOS vous demande explicitement l’accès nécessaire aux favoris de Safari et Chrome.': 'macOS solicita explícitamente el acceso necesario a los marcadores de Safari y Chrome.',
    'Consultez l’aperçu': 'Consulta la vista previa',
    'BookmarkBridge présente les différences et signale les doublons, erreurs ou conflits détectés.': 'BookmarkBridge muestra las diferencias y señala los duplicados, errores o conflictos detectados.',
    'Synchronisez en un clic': 'Sincroniza con un clic',
    'Vous déclenchez l’opération lorsque l’organisation proposée vous convient.': 'Tú inicias la operación cuando la organización propuesta te parece adecuada.',
    'Questions fréquentes': 'Preguntas frecuentes',
    'L’essentiel, sans jargon.': 'Lo esencial, sin jerga.',
    'Mes favoris sont-ils envoyés sur Internet ?': '¿Se envían mis marcadores por Internet?',
    'Non. BookmarkBridge fonctionne localement sur votre Mac, sans cloud ni serveur pour traiter vos favoris.': 'No. BookmarkBridge funciona localmente en tu Mac, sin nube ni servidor que procese tus marcadores.',
    'Mes dossiers et leur ordre sont-ils conservés ?': '¿Se conservan mis carpetas y su orden?',
    'BookmarkBridge est conçu pour préserver les dossiers, sous-dossiers, leur structure et l’ordre des favoris.': 'BookmarkBridge está diseñado para conservar las carpetas, subcarpetas, su estructura y el orden de los marcadores.',
    'Faut-il installer une extension dans Safari ou Chrome ?': '¿Hay que instalar una extensión en Safari o Chrome?',
    'Non. BookmarkBridge est une application macOS autonome : aucune extension ni aucun plugin de navigateur ne sont nécessaires.': 'No. BookmarkBridge es una aplicación macOS independiente: no necesita extensiones ni complementos del navegador.',
    'Comment BookmarkBridge accède-t-il aux favoris ?': '¿Cómo accede BookmarkBridge a los marcadores?',
    'Uniquement après votre autorisation explicite, via les permissions officielles proposées par macOS.': 'Solo tras tu autorización explícita, mediante los permisos oficiales de macOS.',
    'Quand l’application sera-t-elle disponible ?': '¿Cuándo estará disponible la aplicación?',
    'La bêta macOS est disponible gratuitement. Téléchargez le DMG depuis la': 'La beta para macOS está disponible gratis. Descarga el DMG desde la',
    'page de téléchargement': 'página de descarga',
    ', puis glissez BookmarkBridge dans Applications.': ' y arrastra BookmarkBridge a Aplicaciones.',
    'BookmarkBridge pour macOS': 'BookmarkBridge para macOS',
    'Découvrez BookmarkBridge gratuitement sur votre Mac.': 'Descubre BookmarkBridge gratis en tu Mac.',
    'Documentation': 'Documentación',
    'Bêta gratuite pour macOS': 'Beta gratuita para macOS',
    'La version bêta n’est pas encore notariée par Apple. Le message de sécurité affiché au premier lancement est donc attendu : les trois étapes ci-dessous vous guident sans désactiver les protections de votre Mac.': 'Apple aún no ha notarizado la versión beta. Por tanto, el mensaje de seguridad del primer inicio es normal: los tres pasos siguientes te guían sin desactivar las protecciones de tu Mac.',
    'Télécharger le DMG': 'Descargar el DMG',
    'Consulter le manuel PDF': 'Consultar el manual PDF',
    'Version 0.9.3 (build 1) · macOS 26.5 minimum · environ 9,92 Mio.': 'Versión 0.9.3 (build 1) · macOS 26.5 o posterior · unos 9,92 MiB.',
    'Aperçu de BookmarkBridge dans une fenêtre macOS': 'Vista previa de BookmarkBridge en una ventana de macOS',
    'Prêt à installer': 'Listo para instalar',
    'Une application macOS native, locale et sans extension.': 'Una aplicación macOS nativa, local y sin extensiones.',
    'Première ouverture': 'Primera apertura',
    'Trois étapes, une seule fois.': 'Tres pasos, una sola vez.',
    'Installez BookmarkBridge puis autorisez sa première ouverture avec les réglages prévus par macOS. Ces écrans peuvent varier légèrement selon votre version du système.': 'Instala BookmarkBridge y autoriza su primera apertura con los ajustes de macOS. Estas pantallas pueden variar ligeramente según la versión del sistema.',
    'Télécharger et ouvrir BookmarkBridge': 'Descargar y abrir BookmarkBridge',
    'Téléchargez le DMG, ouvrez-le et glissez': 'Descarga el DMG, ábrelo y arrastra',
    'dans': 'a',
    'Applications': 'Aplicaciones',
    '. Lancez ensuite BookmarkBridge depuis ce dossier. macOS affiche le blocage ci-dessous : cliquez sur': '. Después, inicia BookmarkBridge desde esa carpeta. macOS mostrará el aviso siguiente: haz clic en',
    'Terminé': 'Aceptar',
    'Message macOS indiquant que BookmarkBridge ne peut pas être ouvert, avec le bouton Terminé': 'Mensaje de macOS que indica que BookmarkBridge no puede abrirse, con el botón Aceptar',
    'Le premier blocage est normal pour cette bêta non notariée.': 'El primer aviso es normal en esta beta no notarizada.',
    'Autoriser dans Réglages Système': 'Autorizar en Ajustes del Sistema',
    'Ouvrez': 'Abre',
    'Réglages Système': 'Ajustes del Sistema',
    ', puis': ' y después',
    'Confidentialité et sécurité': 'Privacidad y seguridad',
    '. Descendez jusqu’à la section Sécurité et cliquez sur': '. Baja hasta la sección Seguridad y haz clic en',
    'Ouvrir quand même': 'Abrir igualmente',
    'à côté du message concernant BookmarkBridge.': 'junto al mensaje sobre BookmarkBridge.',
    'Réglages Système, rubrique Confidentialité et sécurité, avec le bouton Ouvrir quand même pour BookmarkBridge': 'Ajustes del Sistema, sección Privacidad y seguridad, con el botón Abrir igualmente para BookmarkBridge',
    'Le bouton n’apparaît qu’après une première tentative d’ouverture.': 'El botón solo aparece después de intentar abrir la aplicación por primera vez.',
    'Cliquer sur « Ouvrir quand même »': 'Haz clic en «Abrir igualmente»',
    'Dans la dernière fenêtre de confirmation, cliquez sur': 'En la última ventana de confirmación, haz clic en',
    '. macOS peut demander votre mot de passe ou Touch ID. BookmarkBridge s’ouvrira ensuite normalement.': '. macOS puede pedirte la contraseña o Touch ID. Después, BookmarkBridge se abrirá con normalidad.',
    'Fenêtre de confirmation macOS avec le bouton Ouvrir quand même pour BookmarkBridge': 'Ventana de confirmación de macOS con el botón Abrir igualmente para BookmarkBridge',
    'Vérifiez toujours que le nom affiché est bien « BookmarkBridge ».': 'Comprueba siempre que el nombre mostrado sea «BookmarkBridge».',
    'Gardez les protections macOS actives.': 'Mantén activas las protecciones de macOS.',
    'Cette procédure autorise uniquement BookmarkBridge. Elle ne désactive ni Gatekeeper ni les contrôles de sécurité des autres applications.': 'Este procedimiento solo autoriza BookmarkBridge. No desactiva Gatekeeper ni los controles de seguridad de otras aplicaciones.',
    'Prêt à commencer ?': '¿Todo listo para empezar?',
    'Le DMG contient BookmarkBridge.app et un raccourci vers Applications.': 'El DMG contiene BookmarkBridge.app y un acceso directo a Aplicaciones.',
    'Télécharger BookmarkBridge': 'Descargar BookmarkBridge',
    'Somme SHA-256': 'Suma SHA-256',
    'Manuel utilisateur PDF': 'Manual de usuario PDF',
    'BookmarkBridge compare vos favoris Safari et Chrome et utilise un workflow local adapté à chaque direction, sans cloud.': 'BookmarkBridge compara tus marcadores de Safari y Chrome y utiliza un flujo local adaptado a cada dirección, sin nube.',
    'Safari vers Chrome est transactionnel ; Chrome vers Safari prépare un import additif piloté par Safari.': 'Safari a Chrome es transaccional; Chrome a Safari prepara una importación aditiva gestionada por Safari.',
    'Le moyen le plus simple d\'organiser et synchroniser vos favoris Mac entre Chrome et Safari.': 'La forma más sencilla de organizar y sincronizar tus marcadores de Mac entre Chrome y Safari.',
    'Bêta gratuite 0.9.4 (build 2) · macOS 26.5 minimum.': 'Beta gratuita 0.9.4 (build 2) · macOS 26.5 o posterior.',
    'Créations importables et opérations non prises en charge visibles avant action.': 'Consulta las creaciones importables y las operaciones no compatibles antes de actuar.',
    'workflows adaptés': 'flujos adaptados',
    'écriture Safari directe évitée': 'sin escritura directa en Safari',
    'Deux directions, deux workflows sûrs': 'Dos direcciones, dos flujos seguros',
    'Safari → Chrome se synchronise automatiquement. Chrome → Safari prépare automatiquement un fichier prêt à être importé dans Safari.': 'Safari → Chrome se sincroniza automáticamente. Chrome → Safari prepara automáticamente un archivo listo para importarlo en Safari.',
    'Organisation maîtrisée': 'Organización controlada',
    'Les nouveaux favoris importables conservent leur structure de dossiers ; les limites de l’import Safari sont signalées.': 'Los nuevos marcadores importables conservan su estructura de carpetas; se indican claramente las limitaciones de la importación de Safari.',
    'Examinez chaque différence avant d’agir, y compris les opérations qu’un import Safari additif ne peut pas appliquer.': 'Revisa cada diferencia antes de actuar, incluidas las operaciones que una importación aditiva de Safari no puede aplicar.',
    'Suivez le workflow adapté': 'Sigue el flujo adaptado',
    'Safari → Chrome est appliqué après confirmation. Chrome → Safari ouvre Safari et le fichier HTML à importer.': 'Safari → Chrome se aplica tras la confirmación. Chrome → Safari abre Safari y el archivo HTML que se debe importar.',
    'Safari → Chrome préserve la structure par écriture transactionnelle. Chrome → Safari conserve la structure des nouveaux favoris importés, mais l’import additif ne peut pas appliquer les suppressions, déplacements, renommages ou changements d’URL.': 'Safari → Chrome conserva la estructura mediante escritura transaccional. Chrome → Safari mantiene la estructura de los nuevos marcadores importados, pero la importación aditiva no puede aplicar eliminaciones, movimientos, cambios de nombre ni cambios de URL.',
    'Téléchargez BookmarkBridge 0.9.4 pour macOS et suivez le guide illustré pour autoriser sa première ouverture avec Gatekeeper.': 'Descarga BookmarkBridge 0.9.4 para macOS y sigue la guía ilustrada para autorizar su primera apertura con Gatekeeper.',
    'Version 0.9.4 (build 2) · macOS 26.5 minimum · environ 10,03 Mio.': 'Versión 0.9.4 (build 2) · macOS 26.5 o posterior · unos 10,03 MiB.',
    'Voir le workflow 0.9.4': 'Ver el flujo 0.9.4',
    'Documentation 0.9.4': 'Documentación 0.9.4'
  },
  de: {
    'BookmarkBridge — Synchronisez Safari et Chrome sur macOS': 'BookmarkBridge — Safari und Chrome unter macOS synchronisieren',
    'BookmarkBridge synchronise vos favoris Safari et Chrome tout en préservant leur organisation, directement sur votre Mac et sans cloud.': 'BookmarkBridge synchronisiert Ihre Safari- und Chrome-Lesezeichen und bewahrt deren Organisation – direkt auf Ihrem Mac und ohne Cloud.',
    'Synchronisez vos favoris Safari et Chrome directement sur votre Mac, dans les deux sens et sans cloud.': 'Synchronisieren Sie Ihre Safari- und Chrome-Lesezeichen in beide Richtungen direkt auf Ihrem Mac und ohne Cloud.',
    'Télécharger BookmarkBridge pour macOS': 'BookmarkBridge für macOS laden',
    'Téléchargez BookmarkBridge 0.9.3 pour macOS et suivez le guide illustré pour autoriser sa première ouverture avec Gatekeeper.': 'Laden Sie BookmarkBridge 0.9.3 für macOS und folgen Sie der bebilderten Anleitung, um den ersten Start mit Gatekeeper zu erlauben.',
    'Téléchargez BookmarkBridge et suivez les trois étapes pour autoriser sa première ouverture sur macOS.': 'Laden Sie BookmarkBridge und folgen Sie den drei Schritten, um den ersten Start unter macOS zu erlauben.',
    'fr_FR': 'de_DE',
    'Icône de BookmarkBridge': 'BookmarkBridge-Symbol',
    'Aller au contenu': 'Zum Inhalt springen',
    'BookmarkBridge — Accueil': 'BookmarkBridge — Startseite',
    'Ouvrir le menu': 'Menü öffnen',
    'Fermer le menu': 'Menü schließen',
    'Navigation principale': 'Hauptnavigation',
    'Langue du site': 'Sprache der Website',
    'Fonctionnalités': 'Funktionen',
    'Confidentialité': 'Datenschutz',
    'Fonctionnement': 'Funktionsweise',
    'Télécharger': 'Download',
    'Safari et Chrome.': 'Safari und Chrome.',
    'Enfin synchronisés.': 'Endlich synchron.',
    'Tester gratuitement': 'Kostenlos testen',
    'Découvrir BookmarkBridge': 'BookmarkBridge entdecken',
    'Bêta gratuite 0.9.3 (build 1) · macOS 26.5 minimum.': 'Kostenlose Beta 0.9.3 (Build 1) · ab macOS 26.5.',
    'Safari et Chrome reliés par BookmarkBridge': 'Safari und Chrome durch BookmarkBridge verbunden',
    'Aperçu prêt': 'Vorschau bereit',
    'Ajouts, suppressions, déplacements et modifications visibles avant application.': 'Ergänzungen, Löschungen, Verschiebungen und Änderungen vor dem Anwenden ansehen.',
    'Principes de BookmarkBridge': 'Grundsätze von BookmarkBridge',
    'Traitement local': 'Lokale Verarbeitung',
    'Sans compte': 'Ohne Konto',
    'Sans extension': 'Ohne Erweiterung',
    'Sans publicité ni tracking': 'Ohne Werbung oder Tracking',
    'Les preuves essentielles': 'Das Wichtigste auf einen Blick',
    'navigateurs synchronisés': 'synchronisierte Browser',
    'structure des dossiers conservée': 'Ordnerstruktur bleibt erhalten',
    'donnée envoyée sur Internet': 'Daten über das Internet gesendet',
    'aperçu avant modification': 'Vorschau vor Änderungen',
    'fonctionnement sans compte ni cloud': 'funktioniert ohne Konto oder Cloud',
    'Tout est à sa place': 'Alles bleibt an seinem Platz',
    'Une synchronisation claire, jusque dans les détails.': 'Klare Synchronisierung bis ins Detail.',
    'BookmarkBridge rend une opération complexe lisible et maîtrisable, même sans connaissances techniques.': 'BookmarkBridge macht einen komplexen Vorgang übersichtlich und kontrollierbar – auch ohne technische Vorkenntnisse.',
    'Safari et Chrome en un clic': 'Safari und Chrome mit einem Klick',
    'Lancez la synchronisation depuis une interface unique, sans extension ni plugin à installer.': 'Starten Sie die Synchronisierung über eine einzige Oberfläche – ohne Erweiterung oder Plug-in.',
    'Organisation préservée': 'Organisation bleibt erhalten',
    'Dossiers, sous-dossiers, structure et ordre restent fidèles à votre bibliothèque.': 'Ordner, Unterordner, Struktur und Reihenfolge bleiben Ihrer Bibliothek treu.',
    'Aperçu avant application': 'Vorschau vor dem Anwenden',
    'Examinez les ajouts, suppressions, déplacements et modifications avant d’agir.': 'Prüfen Sie Ergänzungen, Löschungen, Verschiebungen und Änderungen, bevor Sie fortfahren.',
    'Vraiment natif sur Mac': 'Wirklich nativ auf dem Mac',
    'Développé en Swift et SwiftUI pour une expérience familière, fluide et intégrée à macOS.': 'Mit Swift und SwiftUI entwickelt – für ein vertrautes, flüssiges und in macOS integriertes Erlebnis.',
    'Détection intelligente': 'Intelligente Erkennung',
    'Les doublons, erreurs et conflits sont repérés pour vous aider à comprendre les changements.': 'Duplikate, Fehler und Konflikte werden erkannt, damit Sie die Änderungen nachvollziehen können.',
    'Prêt pour vos bibliothèques': 'Bereit für Ihre Bibliotheken',
    'Des performances pensées pour les grandes collections, dans une interface accessible aux utilisateurs non techniques.': 'Leistung für große Sammlungen in einer Oberfläche, die auch ohne technische Vorkenntnisse zugänglich ist.',
    'Privé par conception': 'Datenschutz von Grund auf',
    'Tout se passe sur votre Mac.': 'Alles geschieht auf Ihrem Mac.',
    'BookmarkBridge traite vos favoris localement. Aucun serveur intermédiaire, aucun compte et aucun mécanisme publicitaire ne sont nécessaires.': 'BookmarkBridge verarbeitet Ihre Lesezeichen lokal. Es sind weder Zwischenserver noch Konto oder Werbemechanismen erforderlich.',
    'Aucune donnée de favoris n’est envoyée sur Internet.': 'Keine Lesezeichendaten werden über das Internet gesendet.',
    'Sans compte, publicité ou tracking': 'Ohne Konto, Werbung oder Tracking',
    'Pas d’inscription, de profilage ni de suivi publicitaire.': 'Keine Registrierung, Profilbildung oder Werbeverfolgung.',
    'Permissions officielles macOS': 'Offizielle macOS-Berechtigungen',
    'Les accès sont demandés clairement avec les mécanismes prévus par macOS, sans accès caché.': 'Der Zugriff wird klar über die von macOS vorgesehenen Mechanismen angefordert – ohne versteckten Zugriff.',
    'Vous gardez la main': 'Sie behalten die Kontrolle',
    'L’aperçu vous permet de comprendre les changements avant leur application.': 'In der Vorschau können Sie Änderungen verstehen, bevor sie angewendet werden.',
    'Simple dès le premier lancement': 'Einfach ab dem ersten Start',
    'De vos navigateurs à une vue claire.': 'Von Ihren Browsern zu einer klaren Übersicht.',
    'Autorisez les dossiers': 'Ordnerzugriff erlauben',
    'macOS vous demande explicitement l’accès nécessaire aux favoris de Safari et Chrome.': 'macOS bittet ausdrücklich um den erforderlichen Zugriff auf die Lesezeichen von Safari und Chrome.',
    'Consultez l’aperçu': 'Vorschau prüfen',
    'BookmarkBridge présente les différences et signale les doublons, erreurs ou conflits détectés.': 'BookmarkBridge zeigt die Unterschiede und weist auf erkannte Duplikate, Fehler oder Konflikte hin.',
    'Synchronisez en un clic': 'Mit einem Klick synchronisieren',
    'Vous déclenchez l’opération lorsque l’organisation proposée vous convient.': 'Sie starten den Vorgang, sobald die vorgeschlagene Organisation Ihren Vorstellungen entspricht.',
    'Questions fréquentes': 'Häufig gestellte Fragen',
    'L’essentiel, sans jargon.': 'Das Wesentliche, ohne Fachjargon.',
    'Mes favoris sont-ils envoyés sur Internet ?': 'Werden meine Lesezeichen über das Internet gesendet?',
    'Non. BookmarkBridge fonctionne localement sur votre Mac, sans cloud ni serveur pour traiter vos favoris.': 'Nein. BookmarkBridge arbeitet lokal auf Ihrem Mac, ohne Cloud oder Server zur Verarbeitung Ihrer Lesezeichen.',
    'Mes dossiers et leur ordre sont-ils conservés ?': 'Bleiben meine Ordner und deren Reihenfolge erhalten?',
    'BookmarkBridge est conçu pour préserver les dossiers, sous-dossiers, leur structure et l’ordre des favoris.': 'BookmarkBridge ist darauf ausgelegt, Ordner, Unterordner, deren Struktur und die Reihenfolge der Lesezeichen zu erhalten.',
    'Faut-il installer une extension dans Safari ou Chrome ?': 'Muss ich eine Erweiterung in Safari oder Chrome installieren?',
    'Non. BookmarkBridge est une application macOS autonome : aucune extension ni aucun plugin de navigateur ne sont nécessaires.': 'Nein. BookmarkBridge ist eine eigenständige macOS-App: Browser-Erweiterungen oder Plug-ins sind nicht erforderlich.',
    'Comment BookmarkBridge accède-t-il aux favoris ?': 'Wie greift BookmarkBridge auf Lesezeichen zu?',
    'Uniquement après votre autorisation explicite, via les permissions officielles proposées par macOS.': 'Nur nach Ihrer ausdrücklichen Zustimmung über die offiziellen Berechtigungen von macOS.',
    'Quand l’application sera-t-elle disponible ?': 'Wann wird die App verfügbar sein?',
    'La bêta macOS est disponible gratuitement. Téléchargez le DMG depuis la': 'Die macOS-Beta ist kostenlos verfügbar. Laden Sie das DMG von der',
    'page de téléchargement': 'Download-Seite',
    ', puis glissez BookmarkBridge dans Applications.': ' herunter und ziehen Sie BookmarkBridge anschließend in den Programme-Ordner.',
    'BookmarkBridge pour macOS': 'BookmarkBridge für macOS',
    'Découvrez BookmarkBridge gratuitement sur votre Mac.': 'Entdecken Sie BookmarkBridge kostenlos auf Ihrem Mac.',
    'Documentation': 'Dokumentation',
    'Bêta gratuite pour macOS': 'Kostenlose Beta für macOS',
    'La version bêta n’est pas encore notariée par Apple. Le message de sécurité affiché au premier lancement est donc attendu : les trois étapes ci-dessous vous guident sans désactiver les protections de votre Mac.': 'Die Beta wurde noch nicht von Apple notarisiert. Der Sicherheitshinweis beim ersten Start ist daher zu erwarten: Die folgenden drei Schritte führen Sie durch den Vorgang, ohne die Schutzfunktionen Ihres Mac zu deaktivieren.',
    'Télécharger le DMG': 'DMG laden',
    'Consulter le manuel PDF': 'PDF-Handbuch ansehen',
    'Version 0.9.3 (build 1) · macOS 26.5 minimum · environ 9,92 Mio.': 'Version 0.9.3 (Build 1) · ab macOS 26.5 · ca. 9,92 MiB.',
    'Aperçu de BookmarkBridge dans une fenêtre macOS': 'Vorschau von BookmarkBridge in einem macOS-Fenster',
    'Prêt à installer': 'Bereit zur Installation',
    'Une application macOS native, locale et sans extension.': 'Eine native, lokale macOS-App ohne Erweiterung.',
    'Première ouverture': 'Erster Start',
    'Trois étapes, une seule fois.': 'Drei Schritte, nur einmal.',
    'Installez BookmarkBridge puis autorisez sa première ouverture avec les réglages prévus par macOS. Ces écrans peuvent varier légèrement selon votre version du système.': 'Installieren Sie BookmarkBridge und erlauben Sie den ersten Start über die macOS-Einstellungen. Diese Ansichten können je nach Systemversion leicht abweichen.',
    'Télécharger et ouvrir BookmarkBridge': 'BookmarkBridge laden und öffnen',
    'Téléchargez le DMG, ouvrez-le et glissez': 'Laden und öffnen Sie das DMG und ziehen Sie',
    'dans': 'in',
    'Applications': 'Programme',
    '. Lancez ensuite BookmarkBridge depuis ce dossier. macOS affiche le blocage ci-dessous : cliquez sur': '. Starten Sie BookmarkBridge anschließend aus diesem Ordner. macOS zeigt den folgenden Hinweis: Klicken Sie auf',
    'Terminé': 'Fertig',
    'Message macOS indiquant que BookmarkBridge ne peut pas être ouvert, avec le bouton Terminé': 'macOS-Hinweis, dass BookmarkBridge nicht geöffnet werden kann, mit der Taste „Fertig“',
    'Le premier blocage est normal pour cette bêta non notariée.': 'Der erste Hinweis ist bei dieser nicht notarisierten Beta normal.',
    'Autoriser dans Réglages Système': 'In den Systemeinstellungen erlauben',
    'Ouvrez': 'Öffnen Sie',
    'Réglages Système': 'Systemeinstellungen',
    ', puis': ' und dann',
    'Confidentialité et sécurité': 'Datenschutz & Sicherheit',
    '. Descendez jusqu’à la section Sécurité et cliquez sur': '. Scrollen Sie zum Bereich Sicherheit und klicken Sie auf',
    'Ouvrir quand même': 'Dennoch öffnen',
    'à côté du message concernant BookmarkBridge.': 'neben dem Hinweis zu BookmarkBridge.',
    'Réglages Système, rubrique Confidentialité et sécurité, avec le bouton Ouvrir quand même pour BookmarkBridge': 'Systemeinstellungen, Bereich Datenschutz & Sicherheit, mit der Taste „Dennoch öffnen“ für BookmarkBridge',
    'Le bouton n’apparaît qu’après une première tentative d’ouverture.': 'Die Taste erscheint erst nach einem ersten Öffnungsversuch.',
    'Cliquer sur « Ouvrir quand même »': 'Auf „Dennoch öffnen“ klicken',
    'Dans la dernière fenêtre de confirmation, cliquez sur': 'Klicken Sie im letzten Bestätigungsfenster auf',
    '. macOS peut demander votre mot de passe ou Touch ID. BookmarkBridge s’ouvrira ensuite normalement.': '. macOS fragt möglicherweise nach Ihrem Passwort oder Touch ID. Danach wird BookmarkBridge normal geöffnet.',
    'Fenêtre de confirmation macOS avec le bouton Ouvrir quand même pour BookmarkBridge': 'macOS-Bestätigungsfenster mit der Taste „Dennoch öffnen“ für BookmarkBridge',
    'Vérifiez toujours que le nom affiché est bien « BookmarkBridge ».': 'Vergewissern Sie sich immer, dass der angezeigte Name „BookmarkBridge“ lautet.',
    'Gardez les protections macOS actives.': 'Lassen Sie die macOS-Schutzfunktionen aktiviert.',
    'Cette procédure autorise uniquement BookmarkBridge. Elle ne désactive ni Gatekeeper ni les contrôles de sécurité des autres applications.': 'Dieses Verfahren erlaubt nur BookmarkBridge. Gatekeeper und die Sicherheitsprüfungen anderer Apps bleiben aktiviert.',
    'Prêt à commencer ?': 'Bereit anzufangen?',
    'Le DMG contient BookmarkBridge.app et un raccourci vers Applications.': 'Das DMG enthält BookmarkBridge.app und eine Verknüpfung zum Programme-Ordner.',
    'Télécharger BookmarkBridge': 'BookmarkBridge laden',
    'Somme SHA-256': 'SHA-256-Prüfsumme',
    'Manuel utilisateur PDF': 'PDF-Benutzerhandbuch',
    'BookmarkBridge compare vos favoris Safari et Chrome et utilise un workflow local adapté à chaque direction, sans cloud.': 'BookmarkBridge vergleicht Ihre Safari- und Chrome-Lesezeichen und verwendet für jede Richtung einen passenden lokalen Workflow – ohne Cloud.',
    'Safari vers Chrome est transactionnel ; Chrome vers Safari prépare un import additif piloté par Safari.': 'Safari zu Chrome ist transaktional; Chrome zu Safari bereitet einen additiven Import vor, den Safari selbst ausführt.',
    'Le moyen le plus simple d\'organiser et synchroniser vos favoris Mac entre Chrome et Safari.': 'Die einfachste Möglichkeit, Ihre Mac-Lesezeichen zwischen Chrome und Safari zu organisieren und zu synchronisieren.',
    'Bêta gratuite 0.9.4 (build 2) · macOS 26.5 minimum.': 'Kostenlose Beta 0.9.4 (Build 2) · ab macOS 26.5.',
    'Créations importables et opérations non prises en charge visibles avant action.': 'Importierbare Ergänzungen und nicht unterstützte Vorgänge vor der Aktion anzeigen.',
    'workflows adaptés': 'passende Workflows',
    'écriture Safari directe évitée': 'kein direkter Safari-Schreibzugriff',
    'Deux directions, deux workflows sûrs': 'Zwei Richtungen, zwei sichere Workflows',
    'Safari → Chrome se synchronise automatiquement. Chrome → Safari prépare automatiquement un fichier prêt à être importé dans Safari.': 'Safari → Chrome wird automatisch synchronisiert. Chrome → Safari erstellt automatisch eine Datei, die direkt in Safari importiert werden kann.',
    'Organisation maîtrisée': 'Kontrollierte Organisation',
    'Les nouveaux favoris importables conservent leur structure de dossiers ; les limites de l’import Safari sont signalées.': 'Neue importierbare Lesezeichen behalten ihre Ordnerstruktur; Einschränkungen des Safari-Imports werden klar angezeigt.',
    'Examinez chaque différence avant d’agir, y compris les opérations qu’un import Safari additif ne peut pas appliquer.': 'Prüfen Sie jeden Unterschied, einschließlich Vorgängen, die ein additiver Safari-Import nicht anwenden kann.',
    'Suivez le workflow adapté': 'Dem passenden Workflow folgen',
    'Safari → Chrome est appliqué après confirmation. Chrome → Safari ouvre Safari et le fichier HTML à importer.': 'Safari → Chrome wird nach der Bestätigung angewendet. Chrome → Safari öffnet Safari und die zu importierende HTML-Datei.',
    'Safari → Chrome préserve la structure par écriture transactionnelle. Chrome → Safari conserve la structure des nouveaux favoris importés, mais l’import additif ne peut pas appliquer les suppressions, déplacements, renommages ou changements d’URL.': 'Safari → Chrome bewahrt die Struktur durch transaktionales Schreiben. Chrome → Safari behält die Struktur neu importierter Lesezeichen bei; Löschungen, Verschiebungen, Umbenennungen oder URL-Änderungen können durch den additiven Import jedoch nicht angewendet werden.',
    'Téléchargez BookmarkBridge 0.9.4 pour macOS et suivez le guide illustré pour autoriser sa première ouverture avec Gatekeeper.': 'Laden Sie BookmarkBridge 0.9.4 für macOS und folgen Sie der bebilderten Anleitung, um den ersten Start mit Gatekeeper zu erlauben.',
    'Version 0.9.4 (build 2) · macOS 26.5 minimum · environ 10,03 Mio.': 'Version 0.9.4 (Build 2) · ab macOS 26.5 · ca. 10,03 MiB.',
    'Voir le workflow 0.9.4': 'Workflow 0.9.4 anzeigen',
    'Documentation 0.9.4': 'Dokumentation 0.9.4'
  }
};

const downloadHeroTitles = {
  fr: 'Télécharger<br><span>BookmarkBridge.</span>',
  en: 'Download<br><span>BookmarkBridge.</span>',
  es: 'Descargar<br><span>BookmarkBridge.</span>',
  de: 'BookmarkBridge<br><span>herunterladen.</span>'
};

const translatableAttributes = ['aria-label', 'title', 'alt'];
const sourceTextNodes = [];
const sourceAttributes = [];
const sourceMetadata = [];
let currentLanguage = 'en';

function normalizedLanguage(value) {
  if (typeof value !== 'string') return null;
  const primaryCode = value.trim().toLowerCase().split(/[-_]/)[0];
  return SUPPORTED_LANGUAGES.includes(primaryCode) ? primaryCode : null;
}

function storedLanguage() {
  try {
    return normalizedLanguage(localStorage.getItem(LANGUAGE_STORAGE_KEY));
  } catch {
    return null;
  }
}

function detectedLanguage() {
  const browserLanguages = Array.isArray(navigator.languages) && navigator.languages.length
    ? navigator.languages
    : [navigator.language];

  for (const browserLanguage of browserLanguages) {
    const language = normalizedLanguage(browserLanguage);
    if (language) return language;
  }

  return 'en';
}

function initialLanguage() {
  return storedLanguage() || detectedLanguage();
}

function translated(source, language) {
  if (language === 'fr') return source;
  return translations[language]?.[source] ?? source;
}

function manualPathForLanguage(language) {
  const normalized = normalizedLanguage(language) || 'en';
  return MANUAL_PDF_BY_LANGUAGE[normalized] || MANUAL_PDF_BY_LANGUAGE.en;
}

function gatekeeperImagePath(step, language) {
  const normalized = normalizedLanguage(language) || 'en';
  return GATEKEEPER_IMAGE_BY_LANGUAGE[normalized]?.[step]
    || GATEKEEPER_IMAGE_BY_LANGUAGE.en[step];
}

function captureLocalizableContent() {
  const walker = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_TEXT);
  let node;

  while ((node = walker.nextNode())) {
    if (node.parentElement?.closest('script, style, option')) continue;
    const source = node.nodeValue.trim();
    if (source && Object.values(translations).some((catalog) => source in catalog)) {
      sourceTextNodes.push({ node, source });
    }
  }

  document.querySelectorAll(translatableAttributes.map((attribute) => `[${attribute}]`).join(',')).forEach((element) => {
    translatableAttributes.forEach((attribute) => {
      const source = element.getAttribute(attribute)?.trim();
      if (source && Object.values(translations).some((catalog) => source in catalog)) {
        sourceAttributes.push({ element, attribute, source });
      }
    });
  });

  document.querySelectorAll('meta[name="description"], meta[property^="og:"]').forEach((element) => {
    const source = element.getAttribute('content')?.trim();
    if (source && Object.values(translations).some((catalog) => source in catalog)) {
      sourceMetadata.push({ element, source });
    }
  });
}

function replaceText(node, source, replacement) {
  const value = node.nodeValue;
  const start = value.indexOf(source);
  node.nodeValue = start === -1
    ? replacement
    : `${value.slice(0, start)}${replacement}${value.slice(start + source.length)}`;
}

function menuLabel(isOpen) {
  const source = isOpen ? 'Fermer le menu' : 'Ouvrir le menu';
  return translated(source, currentLanguage);
}

function applyLanguage(language) {
  currentLanguage = normalizedLanguage(language) || 'en';
  document.documentElement.lang = currentLanguage;

  sourceTextNodes.forEach(({ node, source }) => {
    replaceText(node, node.nodeValue.trim(), translated(source, currentLanguage));
  });

  sourceAttributes.forEach(({ element, attribute, source }) => {
    element.setAttribute(attribute, translated(source, currentLanguage));
  });

  sourceMetadata.forEach(({ element, source }) => {
    element.setAttribute('content', translated(source, currentLanguage));
  });

  const downloadHeroTitle = document.querySelector('#download-title');
  if (downloadHeroTitle) downloadHeroTitle.innerHTML = downloadHeroTitles[currentLanguage];

  document.querySelectorAll('[data-manual-link]').forEach((link) => {
    link.setAttribute('href', manualPathForLanguage(currentLanguage));
  });

  document.querySelectorAll('[data-gatekeeper-step]').forEach((image) => {
    image.setAttribute('src', gatekeeperImagePath(image.dataset.gatekeeperStep, currentLanguage));
  });

  document.querySelectorAll('[data-language-selector]').forEach((selector) => {
    selector.value = currentLanguage;
  });

  if (toggle) {
    toggle.setAttribute('aria-label', menuLabel(toggle.getAttribute('aria-expanded') === 'true'));
  }
}

const toggle = document.querySelector('.nav-toggle');
const navigation = document.querySelector('.navigation');
const header = document.querySelector('[data-header]');

captureLocalizableContent();
applyLanguage(initialLanguage());

document.querySelectorAll('[data-language-selector]').forEach((selector) => {
  selector.addEventListener('change', () => {
    const language = normalizedLanguage(selector.value) || 'en';
    try {
      localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
    } catch {
      // Language switching still works when storage is unavailable.
    }
    applyLanguage(language);
  });
});

function closeNavigation() {
  if (!toggle || !navigation) return;
  toggle.setAttribute('aria-expanded', 'false');
  toggle.setAttribute('aria-label', menuLabel(false));
  navigation.classList.remove('open');
}

if (toggle && navigation) {
  toggle.addEventListener('click', () => {
    const isOpen = toggle.getAttribute('aria-expanded') === 'true';
    toggle.setAttribute('aria-expanded', String(!isOpen));
    toggle.setAttribute('aria-label', menuLabel(!isOpen));
    navigation.classList.toggle('open', !isOpen);
  });

  navigation.addEventListener('click', (event) => {
    if (event.target.closest('a')) closeNavigation();
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeNavigation();
  });
}

function updateHeader() {
  if (header) header.classList.toggle('scrolled', window.scrollY > 12);
}

updateHeader();
window.addEventListener('scroll', updateHeader, { passive: true });

const year = document.querySelector('[data-year]');
if (year) year.textContent = new Date().getFullYear();

window.BookmarkBridgeI18n = Object.freeze({
  applyLanguage,
  detectedLanguage,
  gatekeeperImagePath,
  initialLanguage,
  manualPathForLanguage,
  normalizedLanguage,
  supportedLanguages: [...SUPPORTED_LANGUAGES]
});
