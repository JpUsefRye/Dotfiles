PROMPT=$'%{$fg[red]%}┌[%{$reset_color%}\033[1m\033[94;5m%n%{$reset_color%}%{$fg_bold[yellow]%}@%{$fg_bold[cyan]%}%m%{$reset_color%}%{$fg[red]%}][%{$fg[green]%}%~%{$reset_color%}%{$fg[red]%}]> %{$(git_prompt_info)%}%(?,,%{$fg[red]%}[%{$fg_bold[white]%}%?%{$reset_color%}%{$fg[red]%}])
%{$fg[red]%}└──╼%{$fg_bold[yellow]%} λ%{$reset_color%} '
PS2=$' %{$fg[green]%}|>%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[red]%}[%{$fg_bold[white]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}%{$fg[red]%}] "
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}⚡%{$reset_color%}"
