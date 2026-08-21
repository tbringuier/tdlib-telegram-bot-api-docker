# tdlib-telegram-bot-api-docker

Image Docker minimale et sécurisée qui compile et embarque le serveur Telegram Bot API (projet officiel tdlib/telegram-bot-api) à partir des sources. L’image suit les instructions de build officielles amont (Ubuntu 26.04 LTS, clang/libc++), utilise une construction multi‑étapes, s’exécute en utilisateur non‑root, persiste les données dans /data, expose le port 8081 et démarre en mode `--local` par défaut.

## Sommaire
- Présentation
- Prérequis (API ID / API HASH)
- Démarrage rapide (docker run)
- Exemple docker‑compose
- Données persistantes & permissions
- Configuration utile (flags)
- Monter de version / mise à jour
- Construction locale (build)
- Intégration continue & rétention GHCR
- Dépannage

---

## Présentation
Cette image empaquette le binaire `telegram-bot-api` compilé depuis le dépôt amont. Elle est poussée sur GHCR sous:

- `ghcr.io/tbringuier/tdlib-telegram-bot-api-docker:latest` — dernière build
- `ghcr.io/tbringuier/tdlib-telegram-bot-api-docker:upstream-<sha12>` — révision amont précise

Caractéristiques:
- Non‑root (UID 10001), volume persistant `/data`
- Port exposé: 8081 (HTTP)
- Démarrage par défaut: `telegram-bot-api --local --dir=/data`
- Multi‑arch: `linux/amd64` et `linux/arm64`
- Compilé selon la [doc officielle](https://tdlib.github.io/telegram-bot-api/build.html):
  Ubuntu 26.04 LTS, `clang-21` + `libc++`, `CMAKE_BUILD_TYPE=Release`,
  installation dans `/usr/local`
- Runtime minimal: seuls `ca-certificates` et `tzdata` sont ajoutés à `ubuntu:26.04`.
  `libc++` est lié **statiquement** et OpenSSL/zlib/libgcc sont déjà dans l'image de
  base, donc aucun runtime C++ à embarquer. Binaire *stripped*
- Healthcheck sans dépendance externe (sonde TCP via bash, pas de `curl` embarqué)

## Prérequis
Le serveur Bot API nécessite un `api_id` et un `api_hash` obtenus sur le portail officiel Telegram:
1. Se connecter sur https://my.telegram.org
2. Aller dans « API development tools »
3. Créer une application pour obtenir `api_id` et `api_hash`

Ces deux valeurs sont OBLIGATOIRES au lancement du serveur.

## Démarrage rapide (docker run)
Pull de l’image :

```bash
docker pull ghcr.io/tbringuier/tdlib-telegram-bot-api-docker:latest
```

Créer un répertoire de données et lui donner les bons droits (UID interne 10001):

```bash
mkdir -p ./data
chown 10001:10001 ./data
```

Lancer le serveur (remplacez les placeholders):

```bash
docker run -d \
  --name telegram-bot-api \
  -p 8081:8081 \
  -v $(pwd)/data:/data \
  ghcr.io/tbringuier/tdlib-telegram-bot-api-docker:latest \
  --api-id=VOTRE_API_ID \
  --api-hash=VOTRE_API_HASH \
  --local \
  --dir=/data
```

Notes:
- `--local` et `--dir=/data` sont déjà passés par défaut via l’image; les répéter est inoffensif et explicite.
- Pour changer le port HTTP (par défaut 8081), ajoutez `--http-port=9090` et mappez `-p 9090:9090` .

## Exemple docker‑compose
Fichier `docker-compose.yml` minimal:

```yaml
services:
  botapi:
    image: ghcr.io/tbringuier/tdlib-telegram-bot-api-docker:latest
    container_name: telegram-bot-api
    restart: unless-stopped
    ports:
      - "8081:8081"
    environment:
      - TZ=Europe/Paris
    volumes:
      - ./data:/data
    command: [
      "--local",
      "--dir=/data",
      "--api-id=${TELEGRAM_API_ID}",
      "--api-hash=${TELEGRAM_API_HASH}"
    ]
```

Fichier `.env` adjacent:

```bash
TELEGRAM_API_ID=REMPLACEZ_MOI
TELEGRAM_API_HASH=REMPLACEZ_MOI
```

Démarrage:

```bash
docker compose up -d
```

## Données persistantes & permissions
- Le serveur écrit ses fichiers de travail dans `/data` (volume). Conservez ce dossier entre redéploiements.
- L’utilisateur interne est `botapi` (UID 10001). Assurez-vous que le répertoire monté lui est accessible:

```bash
chown -R 10001:10001 ./data
```

## Configuration utile (flags)
Quelques options utiles du binaire `telegram-bot-api`:
- `--api-id`, `--api-hash` (obligatoires)
- `--local` (activé par défaut dans l’image)
- `--dir=/data` (activé par défaut)
- `--http-port=8081` (port HTTP; 8081 par défaut) 
- `--log=/data/server.log`, `--verbosity=4` (journalisation détaillée)

Astuce: exécutez `telegram-bot-api --help` pour la liste complète des flags.

## Monter de version / mise à jour
Avec docker run:
```bash
docker pull ghcr.io/tbringuier/tdlib-telegram-bot-api-docker:latest
```

Avec docker‑compose:
```bash
docker compose pull && docker compose up -d
```

## Construction locale (build)
Le Dockerfile compile depuis la branche amont (par défaut `master`) et installe le binaire dans `/usr/local/bin`.

Construire localement:
```bash
docker build -t tdlib-telegram-bot-api-docker:local .
```

Épingler une révision amont précise (`TELEGRAM_BOT_API_REF` accepte une branche,
un tag **ou** un SHA complet):
```bash
docker build \
  --build-arg TELEGRAM_BOT_API_REF=adfd7f6a8e990272851777eeb3ae0def4216f161 \
  -t tdlib-telegram-bot-api-docker:local .
```

La révision amont réellement utilisée est conservée dans l'image:
```bash
docker run --rm --entrypoint cat tdlib-telegram-bot-api-docker:local \
  /usr/local/share/telegram-bot-api.commit
```

## Intégration continue & rétention GHCR
Le workflow `.github/workflows/docker-publish.yml` tourne **tous les jours** (03:17 UTC),
à chaque push sur `main` (hors fichiers Markdown) et à la demande.

- **Révision amont épinglée**: le SHA de `tdlib/telegram-bot-api` est résolu en amont
  du build, puis passé en `--build-arg`. Les builds sont donc reproductibles et le
  cache n'est invalidé que lorsque l'amont bouge réellement.
- **Cache**: cache GitHub Actions par plateforme (`scope=linux-amd64` / `linux-arm64`),
  sinon les deux jobs de la matrice s'évincent mutuellement. Chaque plateforme est
  construite nativement (pas de QEMU).
- **Mises à jour de sécurité**: une nouvelle image `ubuntu:26.04` change son digest,
  ce qui invalide le cache et déclenche une reconstruction complète automatiquement.
- **Tags stables**: une reconstruction d'un amont inchangé réutilise le même tag.
  Aucun tag n'est créé par run, donc pas d'accumulation.
- **Rétention GHCR**: le job `cleanup` supprime les versions non taguées, partielles
  ou fantômes et ne garde que les 5 tags les plus récents (`latest` est toujours
  préservé). L'action utilisée est consciente des *manifest lists*: les manifestes
  par plateforme référencés par un tag conservé ne sont jamais supprimés, et
  l'option `validate` revérifie l'intégrité multi‑arch après le ménage.
- **Anti‑désactivation du cron**: GitHub désactive les workflows planifiés après
  60 jours sans activité. Le job `keepalive` génère donc de l'activité à chaque run
  en *force‑pushant* la branche `ci-keepalive`, qui ne contient **jamais plus d'un
  commit** (commit orphelin recréé à chaque fois, l'historique est écrasé et non
  allongé). Cette branche est jetable: elle ne contient qu'un `STATUS.md` de
  diagnostic et n'a aucun lien avec `main`. Le push étant fait avec le
  `GITHUB_TOKEN`, il ne redéclenche aucun workflow (pas de boucle).
  Le job appelle ensuite `actions/workflows/<file>/enable`; c'est une simple
  ceinture de sécurité — un workflow déjà désactivé ne peut pas se réactiver
  lui‑même, il faut alors le réactiver depuis l'onglet Actions.

## Dépannage
- Erreur `Unauthorized: invalid api-id/api-hash` → vérifier que vous utilisez bien les identifiants issus de https://my.telegram.org et non BotFather [1,2].
- Permissions sur le volume `/data` → s’assurer que le dossier monté appartient à UID 10001.
- Changement de port → ajuster `--http-port` ET le mapping `-p`.
