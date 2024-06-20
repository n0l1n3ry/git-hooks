# Mode opératoire [ Basé sur le flow Git Flow ]

Permet de faciliter et d'harmoniser la gestion des projets Gitlab.

## Pré-requis

Packages nécessaires :
- git-flow
- curl
- jq

Mise en place de votre environnement

- [ Facultatif ] Génération d'un PAT pour permettre la création automatisée de MR.

Se rendre sur [cette page](https://gitlab.com/-/user_settings/personal_access_tokens)  
Demander la génération d'un Personal Access Token avec les scopes **api** et **read_api**  
Privilégier une date d'expiration courte  
Le conserver, il sera utile sur la section suivante.

- Création du fichier ~/.gitconfig


```ini
[init]
  templateDir = ~/.git_templates

[user]
  name = <Prénom> <NOM>
  email = <yourname>@<mail.provider>

[gitlab]
  fqdn = gitlab.com # A adapter selon votre environnement
  token = glpat-xxx # Laisser vide si vous ne souhaitez pas déclarer un token (Vous ne pourrez pas profiter des MR automatiques)
```

- Création de l'arborescence des hooks

Créer une arborescence de dossiers qui hébergera les templates de hooks

```bash
mkdir -p ~/.git_templates/{_inc,hooks}
```

Créer les différents fichiers Hooks avec les commandes suivantes :

```bash
cat > ~/.git_templates/_inc/vars.sh << "EOF"
# Global common Hook vars
BRANCH=$(git rev-parse --abbrev-ref HEAD)
TOKEN=$(git config --global --get gitlab.token)
GITLAB_FQDN=$(git config --global --get gitlab.fqdn)
PROJECT_NAME=$(git remote get-url origin | sed -e "s/^.*${GITLAB_FQDN}[:/]//" -e "s/.\{4\}$//" -e "s/\//%2F/")

# Colors
INFOCOLOR="\e[1;96m"
WARNCOLOR="\e[1;93m"
DFLTCOLOR="\e[0m"
EOF
```

```bash
cat > ~/.git_templates/_inc/functions.sh << "EOF"
# Opened Merge Requests linked to the actual source/target branches ?
mr_count() {
  RQMR=$(curl -sSX GET --header "PRIVATE-TOKEN: ${TOKEN}" "https://${GITLAB_FQDN}/api/v4/projects/${PROJECT_NAME}/merge_requests?source_branch=${BRANCH}&target_branch=${1}&state=opened" | jq .)
  if $(printf "${RQMR}" | jq .message >/dev/null 2>&1); then
    # Display WARN message
    printf "%b" "${WARNCOLOR}WARNING: API Gitlab call from mr_count func raised the following error\n${RQMR}${DFLTCOLOR}\n"
    MR=-1
  elif [ $(printf "${RQMR}" | jq .[].id | wc -l) -eq 0 ]; then
    MR=0
  else
    printf "%b" "${INFOCOLOR}A Merge Request already exists, it will be upgraded${DFLTCOLOR}\n"
    MR=1
  fi
}

# Merge Request proposal
create_mr() {
  # Allows us to read user input below, assigns stdin to keyboard
  exec < /dev/tty
  printf "Do you want to create a Merge Request (y/n)? "
  read answer
  if [ "${answer}" != "${answer#[Yy]}" ] ;then
    printf "${INFOCOLOR}Create a Merge Request${DFLTCOLOR}\n"
    curl -sX POST \
    --header "PRIVATE-TOKEN: ${TOKEN}" \
    https://${GITLAB_FQDN}/api/v4/projects/${PROJECT_NAME}/merge_requests \
    -d title=${BRANCH} \
    -d source_branch=${BRANCH} \
    -d target_branch=${1} \
    -d description="@all review"
  fi
}
EOF
```

```bash
cat > ~/.git_templates/hooks/post-merge << "EOF"
#! /usr/bin/env sh

# Source vars & functions files
. ~/.git_templates/_inc/vars.sh
. ~/.git_templates/_inc/functions.sh

# Local vars
REF=$(printf "${GIT_REFLOG_ACTION}" | cut -d " " -f2)

case "${REF}" in
  feature/*)
    printf "${INFOCOLOR}Update remote ${BRANCH} branch${DFLTCOLOR}\n"
    git push -u origin ${BRANCH}
  ;;
  release/[0-9]*\.[0-9]*\.*[0-9])
    printf "${INFOCOLOR}Update remote ${BRANCH} branch${DFLTCOLOR}\n"
    git push -u origin ${BRANCH}
  ;;
  [0-9]*\.[0-9]*\.*[0-9])
    ### git flow release finish
    printf "${INFOCOLOR}Update remote ${BRANCH} branch${DFLTCOLOR}\n"
    git push -u origin ${BRANCH}
    printf "${INFOCOLOR}Create a ${REF} tag${DFLTCOLOR}\n"
    git push origin ${REF}
  ;;
  *)
    exit 0
  ;;
esac
EOF
```

```bash
cat > ~/.git_templates/hooks/pre-push << "EOF"
#! /usr/bin/env sh

# Source vars & functions files
. ~/.git_templates/_inc/vars.sh
. ~/.git_templates/_inc/functions.sh

# Here we go
case "${BRANCH}" in
  feature/*) # git flow feature publish
    # MR - target  on defined Git Flow develop branch 
    mr_count ${DEVELOP_BRANCH}
    [ "${MR}" -eq 0 ] && create_mr ${DEVELOP_BRANCH} || continue
  ;;
  release/*) # git flow release publish
    # MR - target on defined Git Flow main branch 
    mr_count ${MASTER_BRANCH}
    [ "${MR}" -eq 0 ] && create_mr ${MASTER_BRANCH} || continue
  ;;
  *)
    exit 0
  ;;
esac
EOF
```

Donner les bons droits aux différents fichiers créés

```bash
chmod 755 ~/.git_templates/hooks/*
```

## Utilisation

Sur chaque projet Gitlab, une première initialisation est nécessaire.  
Les branches develop et main doivent exister.

```bash
git switch main
git swich develop
```

Le démarrage d'une feature ou release doit toujours se faire depuis la branche **develop**.

```bash
git flow init
# Vous pouvez valider les choix par défaut
```

### Création d'une feature

```bash
git flow feature start ma_feature
# Va créer une branche en local avec comme nom feature/ma_feature
# Modifier votre projet
git add -A
git commit -m "Ajout de ma feature"
git flow feature publish
# Aura pour effet de pousser vos modifications sur une branche distante feature/ma_feature
# Une question vous sera posée vous demandant si une MR doit être créée. Utile pour le suivi par les collègues
git flow feature finish
# Aura pour effet de merger la branche feature/ma_feature vers la branch develop (local & distant)
# Merge la MR si elle a été créée.
# Supression de la branche feature/ma_feature (local & distant)
```

### Création d'une release

```bash
git flow release start 0.0.1 # Doit suivre une notation SemVer
# Va créer une branche en local avec comme nom release/0.0.1
# Modifier votre projet
git add -A
git commit -m "Première release"
git flow release publish
# Aura pour effet de pousser vos modifications sur une branche distante release/0.0.1
# Une question vous sera posée vous demandant si une MR doit être créée (Seulement dans le cas où vous aurez renseigné votre PAT dans le fichier de configuration). Utile pour le suivi par les collègues
git flow release finish
# Aura pour effet de merger la branche release/0.0.1 vers la branch main (local & distant)
# Merge la MR si elle a été créée.
# Ajout d'un tag 0.0.1
# Merge le tag 0.0.1 vers la branche develop (local & distant)
# Supression de la branche release/0.0.1 (local & distant)
```
