if status is-interactive

    # Commands to run in interactive sessions can go here

    #function exiftool
    #   /usr/local/bin/Image-ExifTool-12.40/exiftool
    #end

    function hist
       history --show-time="%Y-%m-%d %H:%M:%S " --reverse
    end

    function neovim
       echo "Did you mean nvim?"
    end

    # Append to PATH # (does not work under fish version 3.1)

    fish_add_path --path /usr/sbin
    fish_add_path --path ~/.local/bin

    # Define extra
    set -U XDG_CONFIG_HOME "$HOME/.config"
    
    echo "custom config.fish executed..."

end
