#!/bin/bash
#
# package_installation_library.sh - part of the Linux-Setup project
# Copyright (C) 2025-2026, JustScott, development@justscott.me
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

PROJECT_NAME="Linux-Setup"
SCRIPT_NAME="please"

PRETTY_OUTPUT_LIBRARY="./GeneralLibraries/pretty_output_library.sh"

if ! source "$PRETTY_OUTPUT_LIBRARY" &>/dev/null
then
    printf "\n\e[31m%s\e[0m %s\n" "[Error]" \
        "Couldn't source '$PRETTY_OUTPUT_LIBRARY', this shouldn't happen. Stopping."
    exit 1
fi

install_yay()
{
    if ! command -v yay &>/dev/null
    then
        cd "$HOME"

        if [[ -d "./yay" ]]
        then
            rm -rf "./yay" &>/dev/null
        fi
        git clone https://aur.archlinux.org/yay.git \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Clone yay from the AUR (under ${HOME}/yay)"
        [[ $? -ne 0 ]] && {
            rm -rf yay &>/dev/null
            return 1
        }

        cd yay

        printf "\e[36m%s\e[0m %s\n" "[...]" \
            "Installing yay with makepkg (will prompt for user password)"
        makepkg -si PKGBUILD --noconfirm \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH"
        if [[ $? -ne 0 ]]
        then
            printf "\r\033[2K\e[31m%s\e[0m %s\n" "[Error]" \
                "Installing yay with makepkg"
            cd ..
            rm -rf yay &>/dev/null
            return 1
        fi
        printf "\r\033[2K\e[32m%s\e[0m %s\n" "[Success]" \
            "Installing yay with makepkg"
        cd ..
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" "yay already installed"
    fi

    return 0
}
uninstall_yay()
{
    if pacman -Q yay &>/dev/null
    then
        sudo -v || return 1
        yes | sudo pacman -Rs --noconfirm yay \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Uninstalling yay"
        [[ $? -ne 0 ]] && return 1 
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" "yay not installed"
    fi

    return 0
}


install_qutebrowser()
{
    if ! pacman -Q qutebrowser &>/dev/null
    then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm qutebrowser \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Installing qutebrowser"
        [[ $? -ne 0 ]] && return 1 
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" "qutebrowser already installed"
    fi

    return 0
}
uninstall_qutebrowser()
{
    if pacman -Q qutebrowser &>/dev/null
    then
        sudo -v || return 1
        yes | sudo pacman -Rs --noconfirm qutebrowser \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Uninstalling qutebrowser"
        [[ $? -ne 0 ]] && return 1 
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" "qutebrowser not installed"
    fi

    return 0
}


DOCKER_PACKAGES=(docker docker-compose)
install_docker()
{
    if ! pacman -Q ${DOCKER_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm ${DOCKER_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Installing docker"
        [[ $? -ne 0 ]] && return 1 

        if ! systemctl is-enabled docker &>/dev/null
        then
            sudo -v || return 1
            sudo systemctl enable docker \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Enable the docker service"
            [[ $? -ne 0 ]] && return 1
        fi

        if ! systemctl is-active docker &>/dev/null
        then
            sudo -v || return 1
            sudo systemctl start docker \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Start the docker service"
            [[ $? -ne 0 ]] && return 1
        fi
        
        if ! groups $USER | grep "docker" &>/dev/null
        then
            sudo -v || return 1
            sudo usermod -aG docker $USER \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Add '$USER' to the 'docker' group"
            [[ $? -ne 0 ]] && return 1
        fi

        if [[ -f "${HOME}/.bashrc" ]]; then
            {
                cat "${HOME}/.bashrc" | grep "export DOCKER_BUILDKIT=1" &>/dev/null || \
                    echo -e "\nexport DOCKER_BUILDKIT=1" >> "${HOME}/.bashrc"
                cat "${HOME}/.bashrc" | grep "export COMPOSE_DOCKER_CLI_BUILD=1" &>/dev/null || \
                    echo -e "export COMPOSE_DOCKER_CLI_BUILD=1\n" >> "${HOME}/.bashrc"
            } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Append docker variables to .bashrc if needed"
            [[ $? -ne 0 ]] && return 1
        fi
    else
        printf "\r\e[33m[skipping...]\e[0m %s" "docker already already installed"
    fi

    return 0
}
uninstall_docker()
{
    if systemctl is-active docker &>/dev/null
    then
        sudo -v || return 1
        sudo systemctl stop docker \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Stop the docker service"
        [[ $? -ne 0 ]] && return 1
    fi
    if systemctl is-enabled docker &>/dev/null
    then
        sudo -v || return 1
        sudo systemctl disable docker \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Disable the docker service"
        [[ $? -ne 0 ]] && return 1
    fi

    if groups $USER | grep "docker" &>/dev/null
        then
            sudo -v || return 1
            sudo usermod -rG docker $USER \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Remove '$USER' from the 'docker' group"
            [[ $? -ne 0 ]] && return 1
        fi

    if pacman -Q ${DOCKER_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        yes | sudo pacman -Rs --noconfirm ${DOCKER_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Uninstalling docker"
        [[ $? -ne 0 ]] && return 1 
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" "docker not installed"
    fi
     
    if cat "${HOME}/.bashrc" | grep "export COMPOSE_DOCKER_CLI_BUILD=" &>/dev/null
    then
        sed -i '/export COMPOSE_DOCKER_CLI_BUILD=/d' "${HOME}/.bashrc" \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Remove docker cli build variable from .bashrc"
        [[ $? -ne 0 ]] && return 1
    fi

    if cat "${HOME}/.bashrc" | grep "export DOCKER_BUILDKIT=" &>/dev/null
    then
        sed -i '/export DOCKER_BUILDKIT=/d' "${HOME}/.bashrc" \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Remove docker buildkit variable from .bashrc"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}


PYTHON_PACKAGES=(python python-pip)
install_python()
{
    if ! pacman -Q ${PYTHON_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm ${PYTHON_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Installing python"
        [[ $? -ne 0 ]] && return 1 
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" "python already installed"
    fi

    return 0
}
uninstall_python()
{
    for package in ${PYTHON_PACKAGES[@]}
    do
        if pacman -Q $package &>/dev/null
        then
            sudo -v || return 1
            yes | sudo pacman -Rs --noconfirm $package \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Uninstalling package: $package"
            [[ $? -ne 0 ]] && return 1
        fi
    done

    return 0
}


RUST_PACKAGES=(rustup)
install_rust()
{
    if ! pacman -Q ${RUST_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm ${RUST_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Installing rust"
        [[ $? -ne 0 ]] && return 1 
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" "rust already installed"
    fi

    if rustup show | grep "no active toolchain" &>/dev/null
    then
        rustup default stable >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Set the default toolchain to stable"
        [[ $? -ne 0 ]] && return 1
    fi

    if ! cat "${HOME}/.bashrc" \
        | grep "export PATH=\"\$PATH:\$HOME/.cargo/bin\"" &>/dev/null
    then
        echo "export PATH=\"\$PATH:\$HOME/.cargo/bin\"" \
            >> "${HOME}/.bashrc"
        task_output $! "$STDERR_LOG_PATH" \
            "Add cargo binaries to PATH (in .bashrc)"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
uninstall_rust()
{
    for package in ${RUST_PACKAGES[@]}
    do
        if pacman -Q $package &>/dev/null
        then
            sudo -v || return 1
            yes | sudo pacman -Rs --noconfirm $package \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Uninstalling package: $package"
            [[ $? -ne 0 ]] && return 1
        fi
    done

    if cat "${HOME}/.bashrc" \
        | grep "export PATH=\"\$PATH:\$HOME/.cargo/bin\"" &>/dev/null
    then
        sed -i '/export PATH="$PATH:$HOME\/.cargo\/bin"/d' "${HOME}/.bashrc"
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Remove cargo binaries from PATH (in .bashrc)"
        [[ $? -ne 0 ]] && return 1 
    fi

    return 0
}


install_flatpak()
{
    if ! pacman -Q flatpak &>/dev/null; then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm flatpak \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download flatpak with pacman"
        [[ $? -ne 0 ]] && return 1
    fi

    if command -v flatpak &>/dev/null
    then
        flatpak remote-add --if-not-exists --user flathub \
            https://flathub.org/repo/flathub.flatpakrepo \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Add remote source 'flathub' to flatpak"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
uninstall_flatpak()
{
    if pacman -Q flatpak &>/dev/null; then
        sudo -v || return 1
        yes | sudo pacman -Rs --noconfirm flatpak \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Remove flatpak"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
