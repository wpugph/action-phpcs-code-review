#!/usr/bin/env bash

cd $GITHUB_WORKSPACE

# Checkout to the latest commit of the PR. As the vip-go-ci runner needs the commit id from PR.
# If ref matches *refs/pull*, then an additional PR commit has been added by GH actions, and needs to be skipped.
if [[ "$GITHUB_REF" == *"refs/pull"* ]]; then
  COMMIT_ID=$(git log -n 1 --skip 1 --pretty=format:"%H")
  git checkout -b pr "$COMMIT_ID"
else
  git checkout -b pr "$GITHUB_SHA"
  COMMIT_ID="$GITHUB_SHA"
fi

COMMIT_ID=$GITHUB_SHA

echo 'forked';
git status
git log -n 1 --skip 1 --pretty=format:"%H"
echo 'github sha';
echo $GITHUB_SHA
echo 'commits';
echo "COMMIT ID: $GITHUB_SHA"

stars=$(printf "%-30s" "*")

export RTBOT_WORKSPACE="/home/rtbot/github-workspace"
hosts_file="$GITHUB_WORKSPACE/.github/hosts.yml"

rsync -a "$GITHUB_WORKSPACE/" "$RTBOT_WORKSPACE"
rsync -a /root/vip-go-ci-tools/ /home/rtbot/vip-go-ci-tools
chown -R rtbot:rtbot /home/rtbot/

GITHUB_REPO_NAME=${GITHUB_REPOSITORY##*/}
GITHUB_REPO_OWNER=${GITHUB_REPOSITORY%%/*}

if [[ -n "$VAULT_GITHUB_TOKEN" ]] || [[ -n "$VAULT_TOKEN" ]]; then
  export GH_BOT_TOKEN=$(vault read -field=token secret/rtBot-token)
fi

phpcs_standard=''

defaultFiles=(
  '.phpcs.xml'
  'phpcs.xml'
  '.phpcs.xml.dist'
  'phpcs.xml.dist'
)

phpcsfilefound=1

for phpcsfile in "${defaultFiles[@]}"; do
  if [[ -f "$RTBOT_WORKSPACE/$phpcsfile" ]]; then
      phpcs_standard="--phpcs-standard=$RTBOT_WORKSPACE/$phpcsfile"
      phpcsfilefound=0
  fi
done

if [[ $phpcsfilefound -ne 0 ]]; then
    if [[ -n "$1" ]]; then
      phpcs_standard="--phpcs-standard=$1"
    else
      phpcs_standard="--phpcs-standard=WordPress"
    fi
fi

/usr/games/cowsay "Running with the flag $phpcs_standard"

echo "Running the following command"
echo "/home/rtbot/vip-go-ci-tools/vip-go-ci/vip-go-ci.php --repo-owner=$GITHUB_REPO_OWNER --repo-name=$GITHUB_REPO_NAME --commit=$COMMIT_ID --token=\$GH_BOT_TOKEN --phpcs-path=/home/rtbot/vip-go-ci-tools/phpcs/bin/phpcs --local-git-repo=/home/rtbot/github-workspace --phpcs=true $phpcs_standard --lint=true"

gosu rtbot bash -c "/home/rtbot/vip-go-ci-tools/vip-go-ci/vip-go-ci.php --repo-owner=$GITHUB_REPO_OWNER --repo-name=$GITHUB_REPO_NAME --commit=$COMMIT_ID --token=$GH_BOT_TOKEN --phpcs-path=/home/rtbot/vip-go-ci-tools/phpcs/bin/phpcs --local-git-repo=/home/rtbot/github-workspace --phpcs=true $phpcs_standard --lint=true"
