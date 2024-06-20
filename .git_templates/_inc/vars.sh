# Global common Hook vars
BRANCH=$(git rev-parse --abbrev-ref HEAD)
TOKEN=$(git config --global --get gitlab.token)
GITLAB_FQDN=$(git config --global --get gitlab.fqdn)
PROJECT_NAME=$(git remote get-url origin | sed -e "s/^.*${GITLAB_FQDN}[:/]//" -e "s/.\{4\}$//" -e "s/\//%2F/")

# Colors
INFOCOLOR="\e[1;96m"
WARNCOLOR="\e[1;93m"
DFLTCOLOR="\e[0m"