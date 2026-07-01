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
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "Installing yay is not supported on your distro. Skipping."

    return 1
}
uninstall_yay()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "yay is not installed on your distro. Skipping."

    return 1
}


install_qutebrowser()
{
    if ! dpkg -s qutebrowser &>/dev/null
    then
        sudo -v || return 1
        sudo apt-get install --yes qutebrowser \
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
    if dpkg -s qutebrowser &>/dev/null
    then
        sudo -v || return 1
        sudo apt-get install --yes qutebrowser \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Uninstalling qutebrowser"
        [[ $? -ne 0 ]] && return 1 
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" "qutebrowser not installed"
    fi

    return 0
}


install_docker()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "Installing docker is not supported on your distro. Skipping."

    return 1
}
uninstall_docker()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "docker is not installed on your distro. Skipping."

    return 1
}


PYTHON_PACKAGES=(python3 python3-pip)
install_python()
{
    if ! dpkg -s ${PYTHON_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        sudo apt-get install --yes ${PYTHON_PACKAGES[@]} \
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
        if dpkg -s $package &>/dev/null
        then
            sudo -v || return 1
            sudo apt-get remove --yes $package \
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
    if ! dpkg -s ${RUST_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        sudo apt-get install --yes ${RUST_PACKAGES[@]} \
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
        if dpkg -s $package &>/dev/null
        then
            sudo -v || return 1
            sudo apt-get install --yes $package \
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
    if ! dpkg -s flatpak &>/dev/null; then
        sudo -v || return 1
        sudo apt-get install --yes flatpak \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download flatpak"
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
    if dpkg -s flatpak &>/dev/null; then
        sudo -v || return 1
        sudo apt-get remove --yes flatpak \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Remove flatpak"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}

install_librewolf()
{
    if ! dpkg -s librewolf &>/dev/null
    then
        sudo -v || return 1

        sudo apt-get update >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Update apt"
        [[ $? -ne 0 ]] && return 1

        sudo apt-get install extrepo --yes >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Add extrepo (contains librewolf)"
        [[ $? -ne 0 ]] && return 1

        sudo extrepo enable librewolf >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Enable librewolf repo"
        [[ $? -ne 0 ]] && return 1

        sudo extrepo update librewolf >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Update the librewolf repo"
        [[ $? -ne 0 ]] && return 1

        sudo apt-get update >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Update apt again"
        [[ $? -ne 0 ]] && return 1

        sudo apt-get install librewolf --yes >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Install librewolf"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
uninstall_librewolf()
{
    if dpkg -s librewolf &>/dev/null
    then
        sudo -v || return 1

        sudo apt-get purge librewolf --yes >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Purge librewolf from the system"
        [[ $? -ne 0 ]] && return 1

        sudo extrepo disable librewolf >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Disable librewolf from the extrepo"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}

install_mullvad_vpn()
{
    if ! dpkg -s mullvad-vpn &>/dev/null
    then
        sudo -v || return 1

        sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Download the mullvad-vpn signing key"
        [[ $? -ne 0 ]] && return 1

        echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable stable main" | sudo tee /etc/apt/sources.list.d/mullvad.list >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Add the mullvad-vpn repository to apt"
        [[ $? -ne 0 ]] && return 1

        sudo apt-get update >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Update apt"
        [[ $? -ne 0 ]] && return 1

        sudo apt-get install --yes mullvad-vpn >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Install mullvad-vpn"
        [[ $? -ne 0 ]] && return 1

        echo -e 'Unattended-Upgrade::Origins-Pattern {\n    "origin=repository.mullvad.net,codename=stable";\n};' \
            | sudo tee /etc/apt/apt.conf.d/51mullvad-unattended >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Populate unattended-upgrades file for mullvad-vpn"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
uninstall_mullvad_vpn()
{
    if dpkg -s mullvad-vpn &>/dev/null
    then
        sudo -v || return 1

        if [[ -f "/etc/apt/apt.conf.d/51mullvad-unattended" ]]
        then
            sudo rm "/etc/apt/apt.conf.d/51mullvad-unattended" \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Remove the unattended-upgrades file for mullvad-vpn"
            [[ $? -ne 0 ]] && return 1
        fi

        if systemctl is-active mullvad-daemon &>/dev/null
        then
            sudo systemctl stop mullvad-daemon \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Stop the systemd mullvad-daemon"
            [[ $? -ne 0 ]] && return 1
        fi

        if systemctl is-enabled mullvad-daemon &>/dev/null
        then
            sudo systemctl disable mullvad-daemon >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Disable the systemd mullvad-daemon"
            [[ $? -ne 0 ]] && return 1
        fi

        sudo apt-get purge --yes mullvad-vpn >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Purge mullvad-vpn from the system"
        [[ $? -ne 0 ]] && return 1

        if [[ -f "/usr/share/keyrings/mullvad-keyring.asc" ]]
        then
            sudo rm -f /usr/share/keyrings/mullvad-keyring.asc >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Remove the mullvad-vpn signing key"
            [[ $? -ne 0 ]] && return 1
        fi

        if [[ -f "/etc/apt/sources.list.d/mullvad.list" ]]
        then
            sudo rm -f /etc/apt/sources.list.d/mullvad.list >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Remove the mullvad-vpn repository from apt"
            [[ $? -ne 0 ]] && return 1
        fi

        sudo apt-get update >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Update apt"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
