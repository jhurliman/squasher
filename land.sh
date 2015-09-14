#!/usr/bin/env bash

R="\x1B[1;31m"
G="\x1B[1;32m"
W="\x1B[0m"

error () { echo -e "${R}$1${W}"; exit 1; }

# Sanity check
GIT_DIR=$(git rev-parse --git-dir) || error "Cannot find a git directory in the current folder"

# Confirm the current branch is the correct one
CUR_BRANCH=$(git symbolic-ref --short HEAD) || error "Cannot get current branch.\
 Are you in a detached head state?"
if [[ "$CUR_BRANCH" == "master" ]]; then
  error "Current branch is $CUR_BRANCH. git checkout [your_feature_branch] and try again"
fi

# Make sure there are no unstaged changes
if ! git diff-files --quiet --ignore-submodules --; then
  git diff-files --name-status -r --ignore-submodules -- >&2
  error "Aborting, you have unstaged changes"
fi

################################################################################
# Check for an open pull request
################################################################################

# Parse Github owner+repo from .git/config
OWNER_AND_REPO=$(git remote -v |\
  grep fetch |\
  awk '{print $2}' |\
  sed 's/git@/http:\/\//' |\
  sed 's/com:/com\//' |\
  head -n1 |\
  sed 's/\.git$//' |\
  sed 's/https:\/\/github.com\///') || error "Failed to identify upstream Github repo"

# Load the Github auth token
AUTH_TOKEN=$(cat ~/.github/config.json |\
  grep token |\
  sed 's/[^"]*"token": "\([^"]*\)"/\1/') || error "Failed to load Github auth token from ~/.github/config.json"

# GET /repos/$owner/$repo/pulls?base=$branch
curl "https://api.github.com/repos/$OWNER_AND_REPO/pulls?base=$CUR_BRANCH"
