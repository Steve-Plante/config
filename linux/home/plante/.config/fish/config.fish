if status is-interactive

    # Commands to run in interactive sessions can go here

    alias hist="history --show-time='%Y-%m-%d %H:%M:%S'"
    alias neovim="echo 'Did you mean nvim?'"
    alias sudo-rs="sudo-rs -i"

    # Append to PATH # (does not work under fish version 3.1)

    fish_add_path --path ~/.local/bin
    fish_add_path --path ~/.cargo/bin
    fish_add_path --path /usr/sbin

    # uncomment if cargo installed via https://sh.rustup.rs
    #function fd
    #   /usr/lib/cargo/bin/fd
    #end

    # Define extra
    set -U XDG_CONFIG_HOME "$HOME/.config"
    set -gx VISUAL /usr/bin/nvim
    set -gx EDITOR /usr/bin/nvim
    set -U LESSFILEHIST "-"

    echo "custom config.fish executed..."

end

#if test -f /home/plante/.tbmk/.fish; source /home/plante/.tbmk/.fish; end
