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