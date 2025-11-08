# tdlib-telegram-bot-api-docker

Image Docker minimale et sécurisée qui compile et embarque le serveur Telegram Bot API (projet officiel tdlib/telegram-bot-api) à partir des sources. L’image utilise une construction multi‑étapes sur Ubuntu 24.04, s’exécute en utilisateur non‑root, persiste les données dans /data, expose le port 8081 et démarre en mode `--local` par défaut.

## Sommaire
- Présentation
- Prérequis (API ID / API HASH)
- Démarrage rapide (docker run)
- Exemple docker‑compose
- Données persistantes & permissions
- Configuration utile (flags)
- Monter de version / mise à jour
- Construction locale (build)
- Dépannage

---

## Présentation
Cette image empaquette le binaire `telegram-bot-api` compilé depuis le dépôt amont. Elle est poussée sur GHCR sous:

- ghcr.io/tbringuier/tdlib-telegram-bot-api-docker:latest

Caractéristiques:
- Non‑root (UID 10001), volume persistant `/data`
- Port exposé: 8081 (HTTP)
- Démarrage par défaut: `telegram-bot-api --local --dir=/data`

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

## Dépannage
- Erreur `Unauthorized: invalid api-id/api-hash` → vérifier que vous utilisez bien les identifiants issus de https://my.telegram.org et non BotFather [1,2].
- Permissions sur le volume `/data` → s’assurer que le dossier monté appartient à UID 10001.
- Changement de port → ajuster `--http-port` ET le mapping `-p`.
