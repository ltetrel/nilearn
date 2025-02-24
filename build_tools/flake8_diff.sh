#!/bin/bash

set -e

PROJECT=nilearn/nilearn
PROJECT_URL=https://github.com/$PROJECT.git

echo "Remotes:"
git remote --verbose

# Find the remote with the project name (upstream in most cases)
REMOTE=$(git remote -v | grep $PROJECT | cut -f1 | head -1 || echo '')

# Add a temporary remote if needed. For example this is necessary when
# Travis is configured to run in a fork. In this case 'origin' is the
# fork and not the reference repo we want to diff against.
if [[ -z "$REMOTE" ]]; then
    TMP_REMOTE=tmp_reference_upstream
    REMOTE=$TMP_REMOTE
    git remote add $REMOTE $PROJECT_URL
fi

if [[ "$TRAVIS" == "true" ]]; then
    if [[ "$TRAVIS_PULL_REQUEST" == "false" ]]
    then
        # Travis does the git clone with a limited depth (50 at the time of
        # writing). This may not be enough to find the common ancestor with
        # $REMOTE/main so we unshallow the git checkout
        git fetch --unshallow || echo "Unshallowing the git checkout failed"
    else
        # We want to fetch the code as it is in the PR branch and not
        # the result of the merge into main. This way line numbers
        # reported by Travis will match with the local code.
        BRANCH_NAME=travis_pr_$TRAVIS_PULL_REQUEST
        git fetch $REMOTE pull/$TRAVIS_PULL_REQUEST/head:$BRANCH_NAME
        git checkout $BRANCH_NAME
    fi
elif [[ "$GITHUB_ACTIONS" == true ]]; then
    if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
        PULL_REQUEST_NUMBER=${GITHUB_REF//*pull\//}
        PULL_REQUEST_NUMBER=${PULL_REQUEST_NUMBER//\/merge/}
        BRANCH_NAME=github_pr_$PULL_REQUEST_NUMBER
        git fetch $REMOTE refs/pull/$PULL_REQUEST_NUMBER/head:$BRANCH_NAME
        git checkout $BRANCH_NAME
    fi
fi


echo -e '\nLast 2 commits:'
echo '--------------------------------------------------------------------------------'
git log -2 --pretty=short

git fetch $REMOTE main
REMOTE_MAIN_REF="$REMOTE/main"

# Find common ancestor between HEAD and remotes/$REMOTE/main
COMMIT=$(git merge-base @ $REMOTE_MAIN_REF) || \
    echo "No common ancestor found for $(git show @ -q) and $(git show $REMOTE_MAIN_REF -q)"

if [[ -n "$TMP_REMOTE" ]]; then
    git remote remove $TMP_REMOTE
fi

if [[ -z "$COMMIT" ]]; then
    exit 1
fi

echo -e "\nCommon ancestor between HEAD and $REMOTE_MAIN_REF is:"
echo '--------------------------------------------------------------------------------'
git show --no-patch $COMMIT

echo -e '\nRunning flake8 on the diff in the range'\
     "$(git rev-parse --short $COMMIT)..$(git rev-parse --short @)" \
     "($(git rev-list $COMMIT.. | wc -l) commit(s)):"
echo '--------------------------------------------------------------------------------'

# Conservative approach: diff without context so that code that was
# not changed does not create failures
git diff --unified=0 $COMMIT | flake8 --diff --show-source
echo -e "No problem detected by flake8\n"
