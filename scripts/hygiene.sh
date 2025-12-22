# Put the completion cache in the XDG cache directory instead
autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
