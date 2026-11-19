#!/usr/bin/env bash
#
# Helper: functions.sh
# Description: Development utility functions and git prompt helpers.

# get current branch in git repo
git_status() {
  local BRANCH
  BRANCH="$(git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')"
  if [[ -n "${BRANCH}" ]]; then
    local STAT
    STAT="$(parse_git_dirty)"
    if [[ -n "$STAT" ]]; then
      printf "%s[%s %s]%s" "$(red)" "$BRANCH" "$STAT" "$(ce)"
    else
      printf "%s[%s%s]%s" "$(green)" "$BRANCH" "$STAT" "$(ce)"
    fi
  fi
}

get_repo_basename() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -n "$toplevel" ]]; then
    basename "$toplevel"
  fi
}

get_repo_owner() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -n "$toplevel" ]]; then
    local owner
    owner="$(basename "$(dirname "$toplevel")")"
    printf "%s" "$owner"
  fi
}

# get current status of git repo using fast, built-in Bash pattern matching (no grep process spawns!)
parse_git_dirty() {
  local status
  status="$(git status 2>&1)"
  if [[ "$status" == *"modified:"* ]]; then printf "!"; fi               # dirty
  if [[ "$status" == *"Untracked files"* ]]; then printf "?"; fi         # untracked
  if [[ "$status" == *"new file:"* ]]; then printf "+"; fi               # new files
  if [[ "$status" == *"renamed:"* ]]; then printf ">"; fi                # renamed files
  if [[ "$status" == *"deleted:"* ]]; then printf "x"; fi                # deleted files
  if [[ "$status" == *"Your branch is ahead of"* ]]; then printf "*"; fi # ahead of
}

# ps1 color functions
# add colors like this `red`\$`ce` generates red '$' prompt
ps1_color_open() {
  local red="$1"
  local green="$2"
  local blue="$3"
  printf '\001\033[0;38;2;%s;%s;%sm\002' "$red" "$green" "$blue"
}

green() {
  ps1_color_open 0 254 0
}
red() {
  ps1_color_open 254 0 0
}
blue() {
  ps1_color_open 0 0 254
}
orange() {
  ps1_color_open 254 127 0
}
white() {
  ps1_color_open 254 254 254
}
yellow() {
  ps1_color_open 254 254 0
}

# color end
ce() {
  printf '\001\033[m\002'
}

ts() {
  stty cols 450 2>/dev/null
}

set_terminal_size() {
  local row="$1"
  local col="$2"
  if [[ -z "$row" ]]; then row=70; fi
  if [[ -z "$col" ]]; then col=300; fi
  stty rows "$row" 2>/dev/null
  stty cols "$col" 2>/dev/null
}

git_message() {
  local message=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        echo "Usage: git_message [-m] <commit-message>"
        return 0
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          if [[ -z "$message" ]]; then
            message="$1"
          else
            message="${message} $1"
          fi
          shift
        done
        break
        ;;
      -m)
        shift
        if [[ $# -gt 0 ]]; then
          if [[ -z "$message" ]]; then
            message="$1"
          else
            message="${message}"$'\n\n'"$1"
          fi
          shift
        fi
        ;;
      *)
        if [[ -z "$message" ]]; then
          message="$1"
        else
          message="${message} $1"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$message" ]]; then
    echo "Error: Missing commit message." >&2
    return 1
  fi

  local subject="${message%%$'\n'*}"
  subject="${subject%$'\r'}"
  local cc_regex='^(fix|feat|refactor|ci|chore|docs|test|revert|build|perf|style)(\([^)]+\))?(!)?:\ .+'
  if [[ ! "$subject" =~ $cc_regex ]]; then
    echo "Error: Commit message does not match conventional commit format: '$subject'" >&2
    return 1
  fi
  if [[ ${#subject} -gt 72 ]]; then
    echo "Error: Commit subject line exceeds 72 characters (${#subject}): '$subject'" >&2
    return 1
  fi

  local orig_pwd="$PWD"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not inside a git repository." >&2
    return 1
  fi
  cd "$repo_root" || return 1

  local has_stash=0
  # shellcheck disable=SC2329
  _git_message_cleanup() {
    local exit_code=$?
    if [[ "${1:-}" != "INT" && "${FUNCNAME[1]:-}" != "git_message" ]]; then
      return "$exit_code"
    fi
    trap - RETURN INT
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null || echo ".git")"
    if [[ -d "${git_dir}/rebase-merge" || -d "${git_dir}/rebase-apply" ]]; then
      echo "Aborting in-progress rebase..." >&2
      git rebase --abort 2>/dev/null || true
    fi
    if [[ "$has_stash" -eq 1 ]]; then
      echo "Restoring local stash..." >&2
      (git stash pop --index 2>/dev/null || git stash pop 2>/dev/null) || echo "Warning: Failed to pop stash automatically. Run 'git stash pop' manually." >&2
      has_stash=0
    fi
    cd "$orig_pwd" 2>/dev/null || true
    unset -f _git_message_cleanup 2>/dev/null || true
    return "$exit_code"
  }
  trap '_git_message_cleanup INT; return 130' INT
  trap '_git_message_cleanup' RETURN

  if command -v cspell >/dev/null 2>&1; then
    local cspell_opts=(--no-color --quiet --words-only)
    if [[ -f "${repo_root}/cspell.json" ]]; then
      cspell_opts+=(--config "${repo_root}/cspell.json")
    fi
    local spell_errors
    spell_errors="$(cspell lint stdin "${cspell_opts[@]}" <<<"$message" 2>/dev/null || true)"
    if [[ -n "$spell_errors" ]]; then
      echo "Error: Commit message contains spelling errors:" >&2
      while IFS= read -r line; do
        [[ -n "$line" ]] && echo "  - $line" >&2
      done <<<"$spell_errors"
      return 1
    fi
  fi

  local current
  current="$(git branch --show-current)"
  if [[ -z "$current" ]]; then
    echo "Error: Cannot commit on a detached HEAD." >&2
    return 1
  fi

  local remote
  remote="$(git config "branch.${current}.remote" 2>/dev/null)"
  remote="${remote:-origin}"
  local remote_url
  remote_url="$(git remote get-url "$remote" 2>/dev/null || true)"
  if [[ -z "$remote_url" ]]; then
    echo "Error: Remote '$remote' is not configured." >&2
    return 1
  fi
  if [[ "$remote_url" =~ (^|[:/])rancher/terraform-rancher2-aws(\.git)?/?$ ]]; then
    echo "Error: Target remote '$remote' ($remote_url) points to upstream rancher repo. Pushes must target your personal fork." >&2
    return 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    if git stash push -u -m "temp-git-message-stash"; then
      has_stash=1
    fi
  fi

  git fetch "$remote" "+refs/heads/${current}:refs/remotes/${remote}/${current}" 2>/dev/null || git fetch "$remote" 2>/dev/null || true
  if git rev-parse --verify "${remote}/$current" >/dev/null 2>&1; then
    git branch --set-upstream-to="${remote}/$current" "$current" 2>/dev/null || true
    if ! git pull --rebase "$remote" "$current"; then
      echo "Error: Failed to rebase onto ${remote}/$current." >&2
      return 1
    fi
  fi

  if [[ "$has_stash" -eq 1 ]]; then
    echo "Restoring local stash..." >&2
    if ! git stash pop --index 2>/dev/null && ! git stash pop; then
      echo "Error: Failed to pop stash. Resolve conflicts manually." >&2
      has_stash=0
      return 1
    fi
    has_stash=0
  fi

  # stage all changes, you should delete or ignore files you don't want committed
  echo "staging all changes, you should delete or ignore files you don't want committed"
  git add -A

  if git diff --cached --quiet; then
    echo "Error: No changes to commit." >&2
    return 1
  fi

  local affects_product=0
  if [[ -n "$(git diff --cached --name-only -- internal/ 2>/dev/null)" ]]; then
    affects_product=1
  fi

  local commit_type="${subject%%[(:]*}"
  commit_type="$(echo "$commit_type" | tr '[:upper:]' '[:lower:]')"
  commit_type="${commit_type%!}"
  local breaking_regex='^[a-zA-Z]+(\([^)]+\))?!:'
  local body_breaking_regex='(^|[[:space:]])BREAKING[ -]CHANGE:'
  local has_breaking=0
  if [[ "$subject" =~ $breaking_regex || "$message" =~ $body_breaking_regex ]]; then
    has_breaking=1
  fi

  if [[ "$affects_product" -eq 0 ]]; then
    if [[ "$commit_type" == "feat" || "$commit_type" == "refactor" || "$has_breaking" -eq 1 ]]; then
      echo "Error: Non-product change (outside 'internal/') must NOT use 'feat', 'refactor', or '!' breaking-change indicators." >&2
      return 1
    fi
  fi

  if [[ -x "${repo_root}/.github/workflows/scripts/lint.sh" ]]; then
    if ! "${repo_root}/.github/workflows/scripts/lint.sh" all; then
      echo "Error: Failed lint validation." >&2
      return 1
    fi
  fi
  if [[ -x "${repo_root}/.github/workflows/scripts/test.sh" ]]; then
    if ! "${repo_root}/.github/workflows/scripts/test.sh" all; then
      echo "Error: Failed test suite." >&2
      return 1
    fi
  fi

  # Re-stage any generated files or formatting updates produced during verification
  git add -u

  if git diff --cached --quiet; then
    echo "Error: No staged changes to commit." >&2
    return 1
  fi

  if ! git commit -s -S -m "$message"; then
    echo "Error: Failed to create commit." >&2
    return 1
  fi
  if ! git push -u "$remote" "$current"; then
    echo "Error: Failed to push to ${remote}/${current}." >&2
    return 1
  fi
}
