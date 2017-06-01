# GIT
GIT_UNCOMMITTED="${GIT_UNCOMMITTED:-+}"
GIT_UNSTAGED="${GIT_UNSTAGED:-!}"
GIT_UNTRACKED="${GIT_UNTRACKED:-?}"
GIT_STASHED="${GIT_STASHED:-$}"
GIT_UNPULLED="${GIT_UNPULLED:-⇣}"
GIT_UNPUSHED="${GIT_UNPUSHED:-⇡}"

# Output name of current branch.
git_current_branch() {
  local ref
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # no git repo.
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  fi
  if [[ $1 == "short" ]]; then
    echo ${ref#refs/heads/} | cut -c 1-20
  else
    echo ${ref#refs/heads/}
  fi

}

# Uncommitted changes.
# Check for uncommitted changes in the index.
git_uncomitted() {
  if ! $(git diff --quiet --ignore-submodules --cached); then
    echo -n "${GIT_UNCOMMITTED}"
  fi
}

# Unstaged changes.
# Check for unstaged changes.
git_unstaged() {
  if ! $(git diff-files --quiet --ignore-submodules --); then
    echo -n "${GIT_UNSTAGED}"
  fi
}

# Untracked files.
# Check for untracked files.
git_untracked() {
  if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo -n "${GIT_UNTRACKED}"
  fi
}

# Stashed changes.
# Check for stashed changes.
git_stashed() {
  if $(git rev-parse --verify refs/stash &>/dev/null); then
    echo -n "${GIT_STASHED}"
  fi
}

# Unpushed and unpulled commits.
# Get unpushed and unpulled commits from remote and draw arrows.
git_unpushed_unpulled() {
  # check if there is an upstream configured for this branch
  command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return

  local count
  count="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
  # exit if the command failed
  (( !$? )) || return

  # counters are tab-separated, split on tab and store as array
  count=(${(ps:\t:)count})
  local arrows left=${count[1]} right=${count[2]}

  (( ${right:-0} > 0 )) && arrows+="${GIT_UNPULLED}"
  (( ${left:-0} > 0 )) && arrows+="${GIT_UNPUSHED}"

  [ -n $arrows ] && echo -n "${arrows}"
}

# F1-12: https://github.com/vmalloc/zsh-config/blob/master/extras/function_keys.zsh
fnKeys=('^[OP' '^[OQ' '^[OR' '^[OS' '^[[15~' '^[[17~' '^[[18~' '^[[19~' '^[[20~' '^[[21~' '^[[23~' '^[[24~')
touchBarState=''
npmScripts=()
lastPackageJsonPath=''

function _clearTouchbar() {
  echo -ne "\033]1337;PopKeyLabels\a"
}

function _unbindTouchbar() {
  for fnKey in "$fnKeys[@]"; do
    bindkey -s "$fnKey" ''
  done
}

function _displayDefault() {
  _clearTouchbar
  _unbindTouchbar

  touchBarState=''

  # CURRENT_DIR
  # -----------
  echo -ne "\033]1337;SetKeyLabel=F1=👉 $(echo $(pwd) | awk -F/ '{print $(NF-1)"/"$(NF)}')\a"
  bindkey -s '^[OP' 'pwd \n'

  # GIT
  # ---
  # Check if the current directory is in a Git repository.
  command git rev-parse --is-inside-work-tree &>/dev/null || return

  # Check if the current directory is in .git before running git checks.
  if [[ "$(git rev-parse --is-inside-git-dir 2> /dev/null)" == 'false' ]]; then

    # Ensure the index is up to date.
    git update-index --really-refresh -q &>/dev/null

    # String of indicators
    local indicators=''

    indicators+="$(git_uncomitted)"
    indicators+="$(git_unstaged)"
    indicators+="$(git_untracked)"
    indicators+="$(git_stashed)"
    indicators+="$(git_unpushed_unpulled)"

    [ -n "${indicators}" ] && touchbarIndicators="🔥[${indicators}]" || touchbarIndicators="🙌";

    echo -ne "\033]1337;SetKeyLabel=F2=🎋 $(git_current_branch short)\a"
    echo -ne "\033]1337;SetKeyLabel=F3=$touchbarIndicators\a"
    echo -ne "\033]1337;SetKeyLabel=F4=✉️ push\a";

    # bind git actions
    bindkey -s '^[OQ' 'git branch -a \n'
    bindkey -s '^[OR' 'git status \n'
    bindkey -s '^[OS' "git push origin $(git_current_branch) \n"
  fi

  # AGORAPULSE
  # ------------
  if [[ `git config --get remote.origin.url | grep "agorapulse/platform"` ]]; then
    echo -ne "\033]1337;SetKeyLabel=F5=😎 pulse\a"
    bindkey "${fnKeys[5]}" _displayPulseScripts
  fi
  # PACKAGE.JSON
  # ------------
  if [[ -f package.json ]]; then
    echo -ne "\033]1337;SetKeyLabel=F6=⚡️ npm-run\a"
    bindkey "${fnKeys[6]}" _displayNpmScripts
  fi
}

function _displayPulseScripts() {

  _clearTouchbar
  _unbindTouchbar

  touchBarState='pulse'

  echo -ne "\033]1337;SetKeyLabel=F1=👈 back\a"
  bindkey "${fnKeys[1]}" _displayDefault

  echo -ne "\033]1337;SetKeyLabel=F2=🏃 start\a"
  bindkey -s $fnKeys[2] "pulse start pivotalStoryId"

  echo -ne "\033]1337;SetKeyLabel=F3=☝️ up\a"
  bindkey -s $fnKeys[3] "pulse up \n"

  echo -ne "\033]1337;SetKeyLabel=F4=✉️ commit\a"
  bindkey -s $fnKeys[4] "pulse commit \n"

  echo -ne "\033]1337;SetKeyLabel=F5=🚀 push\a"
  bindkey -s $fnKeys[5] "pulse push \n"

  echo -ne "\033]1337;SetKeyLabel=F6=🎉 finish\a"
  bindkey -s $fnKeys[6] "pulse finish \n"

  echo -ne "\033]1337;SetKeyLabel=F7=🤖 beta\a"
  bindkey -s $fnKeys[7] "pulse beta \n"


}

function _displayNpmScripts() {
  # find available npm run scripts only if new directory
  if [[ $lastPackageJsonPath != $(echo "$(pwd)/package.json") ]]; then
    lastPackageJsonPath=$(echo "$(pwd)/package.json")
    npmScripts=($(node -e "console.log(Object.keys($(npm run --json)).filter(name => !name.includes(':')).sort((a, b) => a.localeCompare(b)).filter((name, idx) => idx < 12).join(' '))"))
  fi

  _clearTouchbar
  _unbindTouchbar

  touchBarState='npm'

  fnKeysIndex=1
  for npmScript in "$npmScripts[@]"; do
    fnKeysIndex=$((fnKeysIndex + 1))
    bindkey -s $fnKeys[$fnKeysIndex] "npm run $npmScript \n"
    echo -ne "\033]1337;SetKeyLabel=F$fnKeysIndex=$npmScript\a"
  done

  echo -ne "\033]1337;SetKeyLabel=F1=👈 back\a"
  bindkey "${fnKeys[1]}" _displayDefault
}

zle -N _displayDefault
zle -N _displayNpmScripts
zle -N _displayPulseScripts

precmd_iterm_touchbar() {
  if [[ $touchBarState == 'npm' ]]; then
    _displayNpmScripts
    return
  fi
  if [[ $touchBarState == 'pulse' ]]; then
    _displayPulseScripts
    return
  fi
  _displayDefault
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd precmd_iterm_touchbar
