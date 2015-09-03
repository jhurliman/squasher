#!/usr/bin/env bash

R="\x1B[1;31m"
G="\x1B[1;32m"
W="\x1B[0m"

error () { echo -e "${R}$1${W}"; exit 1; }

################################################################################

# Sanity check
GIT_DIR=$(git rev-parse --git-dir) || error "Cannot find a git directory in the current folder"

# Confirm the current branch is the correct one
CUR_BRANCH=$(git symbolic-ref --short HEAD) || error "Cannot get current branch.\
 Are you in a detached head state?"
if [[ "$CUR_BRANCH" -eq "master" ]]; then
  error "Current branch is master. git checkout [your_feature_branch] and try again"
fi

# Make sure there are no unstaged changes
if ! git diff-files --quiet --ignore-submodules --; then
  git diff-files --name-status -r --ignore-submodules -- >&2
  error "Aborting, you have unstaged changes"
fi

# Fetch and attempt to merge master into the current branch. Abort on conflict
echo -e "${G}git pull origin master${W}"
git pull origin master || error "Must be able to cleanly merge master. Aborting"

# Get the common ancestor commit of our feature branch and master
ANCESTOR=$(git merge-base "$CUR_BRANCH" master) || error "Failed to find branch\
 point from master to current branch"

# Get user confirmation
echo -en "Squashing commits (rewriting history) in branch ${G}$CUR_BRANCH${W}. Proceed? [y/N] "
read PROCEED
if [[ $PROCEED != "y" && $PROCEED != "Y" ]]; then
  exit 1
fi

# Rename this branch, create a new branch with the original name based on
# current master, then merge squash the renamed feature branch in
git branch -m "$CUR_BRANCH-temp" || error "Failed to create temp branch"
git checkout master || { git branch -m "$CUR_BRANCH"; error "Failed to checkout master branch"; }
git checkout -b "$CUR_BRANCH" || error "Failed to recreate feature branch"
git merge --squash "$CUR_BRANCH-temp" || error "Failed to merge squash feature branch"

# Prompt for a new commit message
while [[ -z "$COMMIT_TITLE" ]]; do
  echo
  echo -en "${G}Enter the final commit title:${W} "
  read COMMIT_TITLE
done

# Prepend the commit message
SQUASH_MSG="$GIT_DIR/SQUASH_MSG"
TMP_MSG=$(mktemp -t gitsquash) || error "mktemp failed"
echo -e "$COMMIT_TITLE\n" | cat - "$SQUASH_MSG" > "$TMP_MSG" && mv "$TMP_MSG" "$SQUASH_MSG"

git commit
git branch -D "$CUR_BRANCH-temp"

echo
echo -e "${G}Success! Squashed branch $CUR_BRANCH"
echo
git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
