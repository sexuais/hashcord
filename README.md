# Hashcord for Discord iOS

Monorepo personnel pour builder Hashcord pour Discord sur iOS, sans Xcode local, via GitHub Actions. Hashcord conserve les contrats Bunny/Vendetta necessaires aux plugins existants.

## Structure

```
.
├── Hashcord/                  # Code JS de Hashcord
│   ├── src/                   # Source TS/TSX du mod
│   ├── scripts/build.mjs      # Script de build esbuild
│   └── package.json
├── HashcordTweak/             # Tweak iOS Theos
│   ├── Sources/               # Hooks Objective-C / Logos
│   ├── Headers/
│   ├── Makefile               # Build Theos → produit un .deb
│   └── control                # Métadonnées package (Name, Version, etc.)
├── plugins/                   # Plugins externes pour Hashcord
│   ├── src/<plugin-id>/       # Sources d'un plugin (manifest.json + code TS/TSX)
│   ├── build.mjs              # Bundle chaque plugin en IIFE pour Hashcord
│   ├── bunny-types.d.ts       # Déclarations TS du global `bunny`
│   └── builds/                # (généré) plugins compilés + repo.json
└── .github/workflows/
   ├── build-bundle.yml       # Build Hashcord + plugins → branche `dist`
    └── build-ipa.yml          # Build le tweak + injecte dans Discord IPA → IPA final
```

## Comment ça marche

1. **`Hashcord`** = code TypeScript du mod. Compile en `hashcord.js`.
2. **`HashcordTweak`** = tweak iOS ecrit en Objective-C/Logos. Il s'injecte dans Discord et charge `hashcord.min.js` avant le bundle JS officiel de Discord.
3. Par defaut, le tweak telecharge le bundle publie sur la branche `dist` de ce depot. L'URL peut etre remplacee dans les reglages du tweak (Custom Load URL).

> **Important** : le bundle JS n'est PAS embarqué dans l'IPA. L'IPA contient seulement le tweak. C'est pour ça qu'on peut rebuild le bundle sans rebuild l'IPA.

---

## Workflow d'installation (résumé)

```
[GitHub Action build-ipa.yml]
         │
         ├── Build HashcordTweak.deb (Theos, macos-15)
         │
         ├── Télécharge Discord.ipa (déchiffré) depuis l'URL fournie
         │
         ├── Injecte le .deb avec `cyan` (pyzule)
         │
         └── Produit `Hashcord.ipa` (non signe) en artifact
                     │
                     ▼
           [Téléchargement local sur ton PC]
                     │
                     ▼
        [Sideloadly avec ton Apple ID gratuit]
                     │
                     ▼
              [Discord moddé sur iPhone]
```

---

## Pré-requis

### Sur ton iPhone / iPad
- iOS 14+ (compatibilite HashcordTweak)
- Une **provisioning** Apple ID (gratuit OK, sinon Apple Developer payant)

### Sur ton PC (Windows ou Mac)
- [**Sideloadly**](https://sideloadly.io/) installé
- Un Apple ID

### Sur GitHub
- Un compte
- Ce repo poussé en privé ou public (peu importe)

---

## Utilisation

### 1. Première installation

1. **Push ce monorepo sur ton GitHub** (instructions plus bas).
2. **Trouve l'URL d'un IPA Discord DÉCHIFFRÉ** (decrypted). Sources possibles :
   - `https://ipa.aldente.cloud/` (cherche "Discord")
   - `https://decrypt.day/`
   - Releases d'autres mods Discord iOS sur GitHub (Bunny, Enmity, etc. — ils ont parfois une release "Discord-decrypted.ipa")
   
   Copie le **lien direct** vers le fichier `.ipa` (qui finit par `.ipa`).

3. **Lance le workflow** :
   - GitHub → Actions → "Build Hashcord IPA" → "Run workflow"
   - Colle l'URL dans `ipa_url`
   - Optionnel : coche "release" pour créer une GitHub Release auto

4. **Attends ~10-15 min**. Quand fini, telecharge l'artifact `Hashcord-discord-X.X.X-ipa`.

5. **Decompresse le ZIP** → tu obtiens `Hashcord.ipa`.

6. **Ouvre Sideloadly** :
   - Connecte ton iPhone
   - Drag & drop `Hashcord.ipa` dans Sideloadly
   - Mets ton Apple ID
   - Clique "Start"
   - Approuve le profil sur ton iPhone (Réglages → Général → VPN et gestion d'appareil)

7. **Lance Discord modde.** Hashcord telecharge son bundle au premier demarrage. L'entree Hashcord apparait dans les parametres.

### 2. Pour utiliser ton propre bundle JS (custom plugins plus tard)

1. Modifie le code dans `Hashcord/src/`
2. Commit + push → le workflow `build-bundle.yml` se déclenche tout seul
3. Il publie `hashcord.js` et `hashcord.min.js` sur la branche `dist` du repo
4. Dans Discord moddé sur iPhone :
   - Settings → General → Developer Settings (à activer)
   - Settings → Developer → "Load from custom URL"
   - Mets : `https://raw.githubusercontent.com/<TON_USER>/<TON_REPO>/dist/hashcord.js`
5. Restart Discord

---

## Build local (optionnel, pour dev)

Pour build/tester le bundle JS en local sans push :

```sh
cd Hashcord
bun install
bun run build         # Genere Hashcord/dist/hashcord.js
bun run serve         # Sert le bundle sur http://localhost:4040/hashcord.js
```

Puis sur iPhone, mets `http://<ip-de-ton-pc>:4040/hashcord.js` comme Custom Load URL.

Le tweak iOS lui ne peut pas être build localement sans macOS+Theos. C'est pour ça qu'on utilise GitHub Actions.

---

## Push sur GitHub (1ère fois)

```sh
git init -b main
git add .
git commit -m "init: Hashcord monorepo + GHA workflows"
gh repo create discord-ipa --private --source=. --push
# OU sans gh-cli :
git remote add origin https://github.com/<TON_USER>/<TON_REPO>.git
git branch -M main
git push -u origin main
```

---

---

## Plugins externes

Ce monorepo héberge aussi un système de **plugins externes** (style Bunny) buildés en parallèle du bundle Hashcord. Chaque plugin vit dans `plugins/src/<id>/` avec son `manifest.json` et son entrée `index.tsx`.

### Build local d'un plugin

```sh
cd plugins
bun install
node build.mjs            # produit plugins/builds/<plugin-id>/{manifest.json,index.js}
                          # et plugins/repo.json
node build.mjs --watch    # rebuild à chaque changement
```

### Ajouter un plugin au repo

1. `mkdir plugins/src/<mon-plugin>`
2. Y mettre :
   - `manifest.json` (cf. `plugins/src/larp/manifest.json` pour l'exemple)
   - `index.tsx` qui termine par `export default definePlugin({ start, stop, SettingsComponent })`
3. `node build.mjs`
4. Commit + push → la GHA `Build Hashcord JS Bundle and Plugins` rebuild et republie sur la branche `dist`

### Plugin Larp (inclus)

Modifie localement ton apparence Discord (visible que par toi) :
- **Username / display name / discriminator** custom
- **Badges** à cocher/décocher (Staff, Partner, HypeSquad, Nitro, Active Developer, …)
- **Date de création** du compte

Tous les overrides sont 100 % locaux — rien n'est envoyé à Discord.

### Utiliser les plugins dans Hashcord sur iPhone

> ⚠ Le repo doit être **public** pour que `raw.githubusercontent.com` réponde sans token.

L'UI Hashcord utilise le format **Vendetta** (URL d'un dossier de plugin avec `manifest.json` + `index.js`), pas le format Bunny avec `repo.json`. **On installe les plugins un par un**, à partir de leur URL dossier.

1. Dans Discord moddé → Paramètres → **Plugins** → bouton **+** (Install a plugin)
2. Pour le plugin **Larp**, colle cette URL :
   ```
   https://raw.githubusercontent.com/sexuais/hashcord/dist/plugins/builds/larp/
   ```
   > Le `/` final n'est pas indispensable, Hashcord l'ajoute tout seul.
3. Confirme l'avertissement "Hold on" (plugins non-proxifiés)
4. Toggle le plugin Larp en ON
5. Un nouvel onglet **"Larp"** apparaît dans les paramètres Discord → configure tes overrides

> Le `repo.json` à la racine de `dist/plugins/` est gardé pour référence/futur — Hashcord ne l'utilise pas pour le moment.

---

## Crédits

- **Hashcord** est derive de Kettu par [@C0C0B01](https://github.com/C0C0B01) (BSD-3-Clause)
- HashcordTweak conserve les composants de tweak issus du projet KettuTweak de [@C0C0B01](https://github.com/C0C0B01)
- Forks/inspirations : Bunny, Pyoncord, Vendetta, Enmity

Voir `Hashcord/LICENSE` et `HashcordTweak/LICENSE` pour les licences originales.
