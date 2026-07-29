# Plateforme QA de BookmarkBridge

Cette plateforme génère des bibliothèques de favoris entièrement anonymisées,
exécute des scénarios déterministes, compare les états obtenus, construit
l'application en Debug et Release, lance les tests Xcode et produit un rapport.

Elle fonctionne exclusivement dans des répertoires temporaires. Aucun script ne
cherche, ne lit ou ne modifie les favoris réels de Safari ou Chrome.

## Lancer toute la plateforme

Depuis la racine du dépôt :

```bash
QA/Scripts/run-qa.sh
```

Cette commande exécute, dans l'ordre :

1. le contrôle de périmètre Git ;
2. la génération et le round-trip des cinq datasets ;
3. tous les scénarios déclaratifs et leurs comparaisons ;
4. le build Debug ;
5. le build Release ;
6. tous les tests unitaires ;
7. les tests UI nécessitant une session macOS graphique ;
8. la génération d'un rapport Markdown et d'un résultat JSON.

Les rapports et journaux sont écrits sous `QA/Reports/`. Ils sont ignorés par
Git. Les données générées et le `DerivedData` vivent par défaut dans un dossier
temporaire système supprimé à la fin du run.

Options utiles :

```bash
# Datasets et scénarios uniquement
QA/Scripts/run-qa.sh --qa-only

# Plateforme complète sans les tests UI (environnement headless)
QA/Scripts/run-qa.sh --unit-only

# Conserver les datasets et DerivedData sous QA/.work/
QA/Scripts/run-qa.sh --keep-workdir
```

## Lancer un scénario unique

```bash
QA/Scripts/run-qa.sh --qa-only --scenario rename
```

`--scenario` est répétable. Les identifiants disponibles se trouvent dans
`QA/Scenarios/catalog.json`.

Le runner autonome des scénarios peut également être utilisé :

```bash
python3 QA/Scripts/run_scenarios.py --scenario rollback
```

## Ajouter ou modifier un dataset

Chaque dataset est défini par un petit fichier
`QA/Datasets/<Nom>/dataset.json`. Il contient :

- `bookmark_count_per_browser` : nombre exact de favoris générés pour Safari et
  Chrome ;
- `shared_ratio` : proportion d'identités initialement communes ;
- `folder_count` et `maximum_depth` : forme de l'arbre ;
- `seed` : graine textuelle assurant la reproductibilité ;
- `pathological` : activation des cas difficiles.

Pour ajouter un dataset :

1. créer son dossier et son `dataset.json` ;
2. ajouter son nom à la validation du catalogue dans
   `QA/Scripts/qa_support.py` ;
3. générer et valider les formats :

```bash
python3 QA/Scripts/generate_datasets.py
```

La génération produit :

```text
<Nom>/
├── canonical.json
├── Safari/Bookmarks.plist
└── Chrome/Default/Bookmarks
```

Le plist Safari est binaire et le fichier Chrome est un document JSON
représentatif. Chaque format est relu puis comparé à l'état canonique, y compris
les doublons.

## Ajouter un scénario

Ajouter une entrée à `QA/Scenarios/catalog.json` avec :

- `id` et `name` ;
- `objective` ;
- `dataset` ;
- `preparation`, liste lisible des préconditions ;
- `steps`, opérations déterministes ;
- `expected`, résultat attendu.

Les actions prises en charge sont : `clear`, `checkpoint`, `sync`,
`rename_bookmark`, `move_bookmark`, `delete_bookmark`, `create_bookmark`,
`move_folder`, `delete_folder`, `merge`, `snapshot`, `restore`,
`interrupt_sync` et `validate_dataset`.

Les scénarios constituent un oracle de données indépendant. Ils ne remplacent
pas les tests Swift : le runner complet exécute aussi `BookmarkBridgeTests` et
`BookmarkBridgeUITests`, qui valident le véritable moteur et l'application.

## Rapports

Chaque exécution crée un dossier horodaté :

```text
QA/Reports/<date>-<commit>/
├── report.md
├── results.json
└── Logs/
```

Le rapport contient la date, la version, le commit, la branche, les datasets,
le nombre de scénarios, succès et échecs, la durée, les validations Xcode et les
écarts. Un modèle réaliste est disponible dans
`QA/Documentation/REPORT-EXAMPLE.md`.

## Garanties de sécurité

- Tous les domaines générés utilisent `.invalid`.
- Aucune donnée personnelle ou issue d'un navigateur n'est utilisée.
- Les scripts n'accèdent jamais à `~/Library/Safari` ou au profil Chrome réel.
- Les scénarios ne travaillent que sur des copies générées.
- Le runner refuse de démarrer si le worktree contient une modification hors
  de `QA/`.
- Aucun rapport, dataset généré ou `DerivedData` n'est versionné.
