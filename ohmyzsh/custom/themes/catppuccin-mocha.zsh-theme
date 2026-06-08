# ============================================================================
#  catppuccin-mocha.zsh-theme
#
#  An oh-my-zsh theme styled with the Catppuccin Mocha palette to match the
#  SketchyBar + tmux rice. Preserves the structure of the previously-active
#  "robbyrussell" theme (exit-status arrow, current dir, git status), restyled
#  with truecolor hex codes.
#
#  Palette:
#    mauve   #cba6f7   green  #a6e3a1   red   #f38ba8
#    text    #cdd6f4   yellow #f9e2af   blue  #89b4fa
#    overlay #6c7086   teal   #94e2d5   peach #fab387
# ============================================================================

# Exit-status arrow: green on success, red on failure (mirrors robbyrussell)
PROMPT="%(?:%F{#a6e3a1}%B%1{➜%}%b :%F{#f38ba8}%B%1{➜%}%b )"
# Current directory in mauve accent
PROMPT+="%F{#cba6f7}%c%f"
# Git status
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%F{#89b4fa}git:(%F{#f38ba8}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{#89b4fa}) %F{#f9e2af}%1{✗%}%f"
ZSH_THEME_GIT_PROMPT_CLEAN="%F{#89b4fa})%f"
