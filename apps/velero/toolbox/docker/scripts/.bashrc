# Velero Toolbox bashrc configuration

export TERM=xterm-256color
export PS1="\[\e[32m\]velero-toolbox\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ "

if [ -f /etc/profile.d/bash_completion.sh ]; then
    source /etc/profile.d/bash_completion.sh
fi

if command -v velero >/dev/null 2>&1; then
    source <(velero completion bash 2>/dev/null)
fi

alias ll="ls -la --color=auto"
alias ls="ls --color=auto"
alias grep="grep --color=auto"

alias vb="velero backup"
alias vs="velero schedule"
alias vr="velero restore"

# Banner for Velero Toolbox
echo -e "\e[1;36m

██╗   ██╗███████╗██╗     ███████╗██████╗  ██████╗     ████████╗ ██████╗  ██████╗ ██╗     ██████╗  ██████╗ ██╗  ██╗
██║   ██║██╔════╝██║     ██╔════╝██╔══██╗██╔═══██╗    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔══██╗██╔═══██╗╚██╗██╔╝
██║   ██║█████╗  ██║     █████╗  ██████╔╝██║   ██║       ██║   ██║   ██║██║   ██║██║     ██████╔╝██║   ██║ ╚███╔╝ 
╚██╗ ██╔╝██╔══╝  ██║     ██╔══╝  ██╔══██╗██║   ██║       ██║   ██║   ██║██║   ██║██║     ██╔══██╗██║   ██║ ██╔██╗ 
 ╚████╔╝ ███████╗███████╗███████╗██║  ██║╚██████╔╝       ██║   ╚██████╔╝╚██████╔╝███████╗██████╔╝╚██████╔╝██╔╝ ██╗
  ╚═══╝  ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝        ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝
\e[0m"

echo ""
echo -e "Type \e[1;36m'velero-schedule'\e[0m to create a new Velero schedule."
echo -e "Type \e[1;36m'velero-schedule --dry-run'\e[0m for a dry run."
echo ""
echo -e "\e[1;33mAvailable alias commands:\e[0m"
echo "  vb = velero backup"
echo "  vs = velero schedule" 
echo "  vr = velero restore"
echo ""
