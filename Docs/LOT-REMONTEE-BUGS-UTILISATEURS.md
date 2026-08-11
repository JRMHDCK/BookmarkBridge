# Lot — Remontée des bugs utilisateurs

## Statut

- **Priorité :** critique — ⭐⭐⭐⭐⭐
- **État :** terminé — phases 1 à 5 implémentées et validées
- **Positionnement :** réalisé avant la création du prochain DMG
- **Impact moteur de synchronisation :** aucun changement de décision métier ;
  instrumentation observationnelle uniquement

## Objectif

Permettre à un utilisateur de signaler un dysfonctionnement en environ deux
clics, avec un e-mail pré-rempli et un rapport technique directement exploitable,
sans collecter automatiquement de données personnelles ni de contenu de favoris.

## Parcours cible

```text
Erreur détectée
    → « Signaler cette erreur »
    → rapport généré localement
    → e-mail préparé pour contact@bookmarkbridge.fr
    → l'utilisateur ajoute éventuellement une phrase
    → « Envoyer »
```

Un second point d'entrée permanent, **« Signaler un bug »**, est disponible dans
le centre d'aide pour les problèmes qui ne déclenchent pas d'erreur visible.

## Périmètre fonctionnel

### Signalement depuis une erreur

- Ajouter **« Signaler cette erreur »** à côté de **« Réessayer »** dans chaque
  état d'erreur récupérable pertinent.
- Conserver le contexte technique de l'opération échouée jusqu'à la création du
  rapport.
- Pré-remplir le signalement avec l'étape et l'erreur correspondantes.

### Signalement manuel

- Ajouter **« Signaler un bug »** dans le centre d'aide.
- Produire un rapport avec le dernier contexte technique disponible.
- Indiquer clairement dans le rapport qu'aucune erreur précise n'a déclenché le
  signalement.

### Rapport de diagnostic

Chaque rapport reçoit un identifiant aléatoire court au format `BB-XXXXXX`, par
exemple `BB-A73F29`. Le rapport contient, lorsque l'information est disponible :

- version de BookmarkBridge et numéro de build ;
- version de macOS ;
- architecture du Mac (`arm64` ou `x86_64`) ;
- date et heure avec fuseau horaire ;
- sens de synchronisation ;
- étape du moteur concernée ;
- type et code interne stable de l'erreur ;
- durée de l'opération ;
- nombres agrégés de favoris, dossiers, correspondances et changements ;
- état des autorisations Safari et Chrome, sans chemin ;
- derniers événements utiles du journal interne ;
- origine du signalement : erreur contextuelle ou aide.

Une valeur absente est rendue par `non disponible` et ne bloque jamais le
signalement.

### E-mail préparé

- Destinataire : `contact@bookmarkbridge.fr`.
- Sujet proposé : `[BookmarkBridge][BB-A73F29] Signalement de bug`.
- Le corps commence par une zone visible invitant l'utilisateur à décrire ce
  qu'il a constaté.
- Un résumé technique compact est inclus dans le corps.
- Le rapport complet est joint en fichier texte lorsque le client mail et macOS
  le permettent.
- Si la pièce jointe n'est pas prise en charge, le rapport complet est ajouté au
  corps du message ou copié dans le presse-papiers avec une explication claire.
- Aucun envoi automatique : l'utilisateur relit et déclenche lui-même l'envoi.

## Confidentialité et sécurité

### Données interdites

Le rapport et le journal interne ne doivent jamais contenir automatiquement :

- URL ou domaine d'un favori ;
- titre d'un favori ;
- nom de dossier de favoris ;
- nom de profil Chrome choisi par l'utilisateur ;
- nom d'utilisateur macOS ;
- chemin local complet ;
- contenu brut des fichiers Safari ou Chrome ;
- security-scoped bookmark, jeton, secret ou donnée d'authentification ;
- empreinte calculée à partir d'un contenu utilisateur si elle permet de le
  corréler durablement.

### Règles de protection

- Le journal accepte uniquement des événements structurés et des valeurs
  explicitement autorisées ; il ne stocke pas de messages d'erreur arbitraires.
- Les chemins sont remplacés à la source par une catégorie neutre, par exemple
  `safari-bookmarks`, `chrome-local` ou `chrome-account`.
- Les erreurs système sont converties en domaine et code ; leur description
  libre n'est pas enregistrée sans assainissement.
- Le rapport est généré localement. BookmarkBridge n'ajoute aucun service réseau
  ni télémétrie silencieuse.
- Le fichier temporaire du rapport est supprimé après remise au client mail ou
  au prochain démarrage si sa suppression immédiate n'est pas garantie.

## Journal technique interne

Le journal est un tampon circulaire borné aux événements nécessaires pour
reconstituer la fin d'une opération.

- **Capacité initiale :** 200 événements maximum.
- **Rétention initiale :** sept jours maximum.
- **Format :** événement structuré horodaté, niveau, composant, étape, résultat,
  code et métriques agrégées autorisées.
- **Écriture :** locale uniquement, sérialisée et résistante à une fermeture
  inattendue.
- **Lecture :** les 50 derniers événements pertinents sont inclus dans un
  rapport, dans la limite de sept jours.
- **Purge :** automatique par âge et capacité ; aucune conservation indéfinie.

Exemple autorisé :

```text
2026-08-11T16:17:32+02:00 | sync | chrome-read | failure |
code=access-denied | folders=0 | bookmarks=0 | duration_ms=184
```

## Architecture proposée

La fonctionnalité reste séparée du moteur et dépend de protocoles injectés.

```text
View d'erreur / Centre d'aide
    → BugReportViewModel
        → DiagnosticReportBuilding
        → DiagnosticEventReading
        → BugReportEmailComposing

Moteur et services existants
    → DiagnosticEventRecording
        → tampon local borné et assaini
```

Types principaux envisagés :

- `DiagnosticEvent` : événement structuré, immuable et `Sendable` ;
- `DiagnosticContext` : sens, étape, durée, métriques et autorisations ;
- `DiagnosticErrorCode` : codes internes stables et typés ;
- `DiagnosticReport` : modèle du rapport avant rendu texte ;
- `DiagnosticEventStore` : stockage borné derrière un protocole ;
- `DiagnosticReportBuilder` : assemblage et assainissement ;
- `BugReportEmailComposer` : ouverture du client mail et stratégie de repli.

Le moteur ne dépend que de `DiagnosticEventRecording`. Les événements restent
observationnels : ils ne modifient jamais le calcul, la planification ou
l'exécution d'une synchronisation.

## Découpage de réalisation

### 1. Contrat de confidentialité et modèles

- [x] Définir la liste blanche des champs autorisés.
- [x] Créer les modèles et codes d'erreur stables.
- [x] Tester que toute donnée interdite est supprimée ou refusée.

### 2. Journal local borné

- [x] Implémenter l'enregistrement structuré, la limite de 200 événements et la
  purge après sept jours.
- [x] Instrumenter les étapes déjà identifiables sans modifier leur comportement.
- [x] Tester la capacité, l'ordre, la purge et la résistance aux événements
  invalides.

### 3. Génération du rapport

- [x] Collecter les informations système et applicatives autorisées.
- [x] Assembler un rapport déterministe et lisible.
- [x] Générer l'identifiant `BB-XXXXXX` et le fichier texte temporaire.
- [x] Tester les valeurs absentes, les métriques et l'absence de données privées.

### 4. Préparation de l'e-mail

- [x] Préparer destinataire, sujet, corps et pièce jointe.
- [x] Implémenter un repli sans pièce jointe avec copie du rapport dans le
  presse-papiers.
- [x] Garantir que l’application ouvre uniquement un brouillon et ne déclenche
  jamais son envoi.
- [x] Vérifier qu'aucun e-mail n'est envoyé sans action explicite.

### 5. Intégration UX

- [x] Ajouter le bouton contextuel à côté de **« Réessayer »**.
- [x] Ajouter le bouton permanent au centre d'aide.
- [x] Couvrir le parcours erreur et le parcours manuel par des tests d'interface.
- [x] Vérifier l'accessibilité, la localisation française et anglaise et le nombre
  d'actions nécessaires.

Les deux tests d’interface sont déterministes et remplacent l’ouverture réelle
du client mail. Ils couvrent le signalement manuel et le signalement contextuel
depuis une erreur, sans créer ni envoyer de message réel.

## Validation finale

Validation effectuée le 11 août 2026 :

- suite complète `BookmarkBridgeTests` réussie ;
- parcours UI manuel **« Signaler un bug »** réussi ;
- parcours UI contextuel **« Signaler cette erreur »** réussi ;
- ouverture réelle d’un brouillon avec Apple Mail, destinataire, sujet, corps et
  rapport joint validée manuellement ;
- build Release réussi sans avertissement nouveau lié au lot ;
- absence de DMG, de télémétrie réseau et d’envoi automatique confirmée.

Le lanceur général `QA/Scripts/run-qa.sh` n’est pas utilisé comme verdict pour
ce lot : son garde-fou refuse intentionnellement un arbre de travail contenant
des modifications applicatives hors de `QA/`. Les suites Xcode complètes et les
tests UI ciblés constituent la validation de référence du lot.

## Critères d'acceptation

Le lot est terminé lorsque :

1. toute erreur récupérable ciblée propose **« Réessayer »** et
   **« Signaler cette erreur »** au même endroit ;
2. le centre d'aide propose toujours **« Signaler un bug »** ;
3. deux actions au maximum suffisent pour obtenir un brouillon d'e-mail prêt à
   être envoyé, hors saisie libre et clic final d'envoi ;
4. le destinataire, le sujet, l'identifiant et le résumé technique sont
   pré-remplis ;
5. un rapport texte complet est joint lorsque le système le permet, avec un
   repli fonctionnel sinon ;
6. le rapport contient tous les champs disponibles du périmètre fonctionnel ;
7. aucun rapport ni événement de journal ne contient l'une des données
   interdites ;
8. le journal respecte les limites de capacité et de rétention ;
9. aucun réseau ni serveur de télémétrie n'est ajouté ;
10. aucun e-mail n'est envoyé automatiquement ;
11. les tests unitaires, d'intégration et d'interface concernés réussissent ;
12. le build Release ne produit aucun avertissement nouveau.

## Hors périmètre

- Envoi automatique vers une API ou une plateforme de suivi.
- Collecte de télémétrie en arrière-plan.
- Capture d'écran automatique.
- Inclusion automatique des fichiers de favoris ou des journaux système globaux.
- Modification du comportement fonctionnel du moteur de synchronisation.
- Tableau de bord serveur de suivi des rapports.

## Décisions retenues

- Rétention du journal : sept jours et 200 événements maximum.
- Client de messagerie : application configurée par défaut dans macOS ; Apple
  Mail constitue le parcours de référence validé avec pièce jointe.
- Prévisualisation séparée du rapport : différée, afin de conserver le parcours
  nominal en deux actions ; le brouillon reste entièrement relisible avant envoi.
