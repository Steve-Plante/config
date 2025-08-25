# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
test -s ~/.alias && . ~/.alias || true
HISTTIMEFORMAT='%d/%m/%y %T '
. "$HOME/.cargo/env"
#Uncomment below exports if config.fish is not setting the default system editor.
export VISUAL=/usr/bin/nvim
export EDITOR="$VISUAL"
alias sudo='sudo -E'
alias sudo-rs='sudo-rs -i'
echo "custom .bashrc executed..."
