#!/bin/bash
#
# install.sh - part of the Linux-Setup project
# Copyright (C) 2023-2026, JustScott, development@justscott.me
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

#
# Creates soft links to all of the configuration files in this repository
#  throughout the system.
#

PRETTY_OUTPUT_LIBRARY="./GeneralLibraries/pretty_output_library.sh"

if ! source "$PRETTY_OUTPUT_LIBRARY" &>/dev/null
then
    printf "\n\e[31m%s\e[0m %s\n" "[Error]" \
        "Could'nt source '$PRETTY_OUTPUT_LIBRARY', this shouldn't happen. Stopping."
    exit 1
fi

CONFIGS_DIRECTORY="$(pwd)/Configurations"

REQUIRED_COMMANDS=(mkdir grep printf curl)

ensure_commands_installed()
{
    for cmd in ${REQUIRED_COMMANDS[@]}
    do
        if ! command -v $cmd &>/dev/null
        then
            printf "\n\n\e[31m%s %s\e[0m\n\n" \
                "[!] Missing required command: '$cmd'."
            return 1
        fi
    done

    return 0
}

ensure_commands_installed || exit $?

configure_bashrc_extension()
{
    local extension_path="${CONFIGS_DIRECTORY}/bashrc_extension"
    if ! grep "^source $extension_path$" "${HOME}/.bashrc" &>/dev/null
    then
        echo "source $extension_path" >> "${HOME}/.bashrc" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Source bashrc_extension in ${HOME}/.bashrc"
    fi
} 

configure_bashrc_secrets()
{
    local secrets_path="\$HOME/.bashrc_secrets"
    if ! grep "^test -f $secrets_path && source $secrets_path$" "${HOME}/.bashrc" &>/dev/null
    then
        echo "test -f $secrets_path && source $secrets_path" >> "${HOME}/.bashrc" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Source bashrc_extension in ${HOME}/.bashrc"
    fi
}

configure_vim()
{
    if command -v vim &>/dev/null
    then
        if ! cat "${HOME}/.vimrc" &>/dev/null
        then
            ln -sf "${CONFIGS_DIRECTORY}/nvim/init.vim" \
                 "${HOME}/.vimrc" \
                 >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Create soft link to '\$HOME/.vimrc'"
        fi
    fi
}

configure_vim_plug()
{
    if command -v nvim &>/dev/null
    then
        # Install Vim-Plug for adding pluggins to vim and neovim
        if ! [[ -f "${HOME}/.local/share/nvim/site/autoload/plug.vim" ]]
        then
            mkdir -p "${HOME}/.local/share/nvim/site/autoload" &>/dev/null

            curl -Lo "${HOME}/.local/share/nvim/site/autoload/plug.vim" \
                https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Download & Install vim-plug"

            nvim -c "PlugInstall | qall" --headless \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Install plugins with vim-plug"
        fi
    fi
}

configure_git()
{
    if command -v git &>/dev/null
    then
        local git_config="$(git config --list)"

        if ! echo "$git_config" | grep "user.email=development@justscott.me" \
            &>/dev/null
        then
            git config --global user.email development@justscott.me \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Configure global git user.email as development@justscott.me"
        fi
        if ! echo "$git_config" | grep "user.name=JustScott" \
            &>/dev/null
        then
            git config --global user.name JustScott \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Configure global git user.name as JustScott"
        fi

        if command -v bat &>/dev/null
        then
            if ! echo "$git_config" | grep \
                "core.pager=bat --paging=always --style=changes" \
                &>/dev/null
            then
                git config --global core.pager \
                    "bat --paging=always --style=changes" \
                    >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
                task_output $! "$STDERR_LOG_PATH" \
                    "Configure global git core.pager as bat"
            fi
        fi
    fi
}

configure_gnome()
{
    if ! command -v gsettings &>/dev/null
    then
        return 0
    fi

    if [[ -s "/etc/profile.d/vte.sh" ]]
    then
        if ! grep "^source /etc/profile.d/vte.sh$" "${HOME}/.bashrc" &>/dev/null
        then
            echo -e "\n#Opens new tabs in the current working directory" >> ~/.bashrc
            echo "source /etc/profile.d/vte.sh" >> ~/.bashrc
        fi
    fi

    declare -A shortcut_keybinds=(
        ["Browser"]="<Alt>b"
        ["Terminal"]="<Shift><Alt>Return"
        ["Brightness Up"]="<Alt>Right"
        ["Brightness Down"]="<Alt>Left"
        ["Volume Up"]="<Alt>Up"
        ["Volume Down"]="<Alt>Down"
    )

    declare -A shortcut_commands=(
        ["Browser"]="xdg-open https://duckduckgo.com"
        ["Terminal"]="gnome-terminal"
        ["Brightness Up"]="brightnessctl set 10%+"
        ["Brightness Down"]="brightnessctl set 10%-"
        ["Volume Up"]="pamixer --increase 5"
        ["Volume Down"]="pamixer --decrease 5"
    )

    keybind_locations="["
    for ((count=0;count<${#shortcut_keybinds[@]};count++)); do
        keybind_locations+="'/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom${count}/'"
        if [[ $count == $((${#shortcut_keybinds[@]}-1)) ]]
        then
            keybind_locations+="]"
        else
            keybind_locations+=", "
        fi
    done

    CUSTOM_KEYBINDINGS_URI="org.gnome.settings-daemon.plugins.media-keys custom-keybindings"
    if [[ "$(gsettings get $CUSTOM_KEYBINDINGS_URI)" != "$keybind_locations" ]]
    then
        gsettings set $CUSTOM_KEYBINDINGS_URI "$keybind_locations" >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Set Keybinds Location"
        [[ $? -ne 0 ]] && return 1
    fi

    keybind_index=0
    for name in "${!shortcut_keybinds[@]}"
    do
        binding="${shortcut_keybinds[$name]}"
        command="${shortcut_commands[$name]}"

        KEYBIND_URI="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom${keybind_index}/"

        SHORTCUT_BINDING_URI="$KEYBIND_URI binding"
        if [[ "$(gsettings get $SHORTCUT_BINDING_URI)" != "'$binding'" ]]
        then
            gsettings set $SHORTCUT_BINDING_URI "$binding" \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Set keybind: '$binding'"
            [[ $? -ne 0 ]] && return 1
        fi

        SHORTCUT_NAME_URI="$KEYBIND_URI name"
        if [[ "$(gsettings get $SHORTCUT_NAME_URI)" != "'$name'" ]]
        then
            gsettings set $SHORTCUT_NAME_URI "$name" \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Set keybind name: '$name'"
            [[ $? -ne 0 ]] && return 1
        fi

        SHORTCUT_COMMAND_URI="$KEYBIND_URI command"
        if [[ "$(gsettings get $SHORTCUT_COMMAND_URI)" != "'$command'" ]]
        then
            gsettings set $SHORTCUT_COMMAND_URI "$command" \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Set keybind command: '$command'"
            [[ $? -ne 0 ]] && return 1
        fi

        ((keybind_index++))
    done

    CLOSE_WINDOW_URI="org.gnome.desktop.wm.keybindings close"
    if [[ "$(gsettings get $CLOSE_WINDOW_URI)" != "['<Shift><Alt>c']" ]]
    then
        gsettings set $CLOSE_WINDOW_URI "['<Shift><Alt>c']" \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Change close window from Alt+F4 to <Shift><Alt>c"
    fi

    COLOR_SCHEME_URI="org.gnome.desktop.interface color-scheme"
    if [[ "$(gsettings get $COLOR_SCHEME_URI)" != "'prefer-dark'" ]]
    then
        gsettings set $COLOR_SCHEME_URI "'prefer-dark'" \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Set Desktop Color Theme to Dark"
    fi

    TERMINAL_PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d \')
    TERMINAL_PROFILE_URI="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${TERMINAL_PROFILE_ID}/"

    if [[ -n $TERMINAL_PROFILE_ID ]]
    then
        TERMINAL_FONT="$TERMINAL_PROFILE_URI font"
        if [[ "$(gsettings get $TERMINAL_FONT)" != "'Monospace 14'" ]]
        then
            gsettings set $TERMINAL_FONT "'Monospace 14'" \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Set Font Name & Size"
        fi


        DEFAULT_SIZE_COLUMNS_SETTING="$TERMINAL_PROFILE_URI default-size-columns"
        if [[ "$(gsettings get $DEFAULT_SIZE_COLUMNS_SETTING)" != "88" ]]
        then
            gsettings set $DEFAULT_SIZE_COLUMNS_SETTING 88 \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Set Terminal Size in Columns"
        fi

        DEFAULT_SIZE_ROWS_SETTING="$TERMINAL_PROFILE_URI default-size-rows"
        if [[ "$(gsettings get $DEFAULT_SIZE_ROWS_SETTING)" != "20" ]]
        then
            gsettings set $DEFAULT_SIZE_ROWS_SETTING 20 \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Set Terminal Size in Rows"
        fi

        BELL_SETTING="$TERMINAL_PROFILE_URI audible-bell"
        if [[ "$(gsettings get $BELL_SETTING)" != "false" ]]
        then
            gsettings set $BELL_SETTING false >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Turn off the Terminal Bell"
        fi
    else
        printf "\e[33m%s\e[0m\n" \
            "[Skip] Failed to get terminal profile... skipping related commands"
    fi

    NEXT_TAB_URI="org.gnome.Terminal.Legacy.Keybindings:/org/gnome/terminal/legacy/keybindings/ next-tab"
    if [[ "$(gsettings get $NEXT_TAB_URI)" != "'<Control>Return'" ]]
    then
        gsettings set $NEXT_TAB_URI '<Control>Return' \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Set Keybind: Switch to the Next Terminal Tab = <Control>Return"
    fi

    PREVIOUS_TAB_URI="org.gnome.Terminal.Legacy.Keybindings:/org/gnome/terminal/legacy/keybindings/ prev-tab"
    if [[ "$(gsettings get $PREVIOUS_TAB_URI)" != "'<Control>BackSpace'" ]]
    then
        gsettings set $PREVIOUS_TAB_URI '<Control>BackSpace' \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Set Keybind: Switch to the Previous Terminal Tab = <Control>BackSpace"
    fi

    return 0
}

configure_bat()
{
    if ! [[ -d "${HOME}/.bin" ]]
    then
        printf "\n\e[31m%s\e[0m\n" \
            "[ERROR] add-please-to-path should've created the $HOME/.bin" \
            "directory, but it doesn't exist. This shouldn't happen."
        return 1
    fi

    if ! command -v bat &>/dev/null
    then
        if command -v batcat &>/dev/null
        then
            if ! [[ -L "${HOME}/.bin/bat" ]]
            then
                ln -sf "$(command -v batcat)" "${HOME}/.bin/bat" \
                    >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
                task_output $! "$STDERR_LOG_PATH" \
                    "soft link batcat to bat"
            fi
        fi
    fi

    return 0
}

configure_tool()
{
    local tool="$1"
    shift
    local file_names=("$@")

    if command -v $tool &>/dev/null
    then
        if ! [[  -d "${HOME}/.config/${tool}" ]]
        then
            mkdir -p "${HOME}/.config/${tool}" \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Create the '\$HOME/.config/${tool}' directory"
        fi

        for file_name in ${file_names[@]}
        do
            if ! cat "${HOME}/.config/${tool}/${file_name}" &>/dev/null
            then
                ln -sf "${CONFIGS_DIRECTORY}/${tool}/${file_name}" \
                     "${HOME}/.config/${tool}/" \
                     >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
                task_output $! "$STDERR_LOG_PATH" \
                    "Create soft link to '\$HOME/.config/${tool}/${file_name}'"
            fi
        done
    fi 
}

configure_tool nvim init.vim
configure_tool bat config
configure_tool mpv mpv.conf
configure_tool ytfzf conf.sh
configure_tool calcurse conf
configure_tool lf lfrc previewer.sh
configure_tool newsboat config urls
configure_tool qutebrowser blocked-hosts quickmarks

configure_bashrc_extension
configure_bashrc_secrets
configure_vim
configure_vim_plug
configure_git
configure_gnome
configure_bat
