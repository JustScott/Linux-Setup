#!/bin/bash
#
# setup_installation_library.sh - part of the Linux-Setup project
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

PRETTY_OUTPUT_LIBRARY="./GeneralLibraries/pretty_output_library.sh"

if ! source "$PRETTY_OUTPUT_LIBRARY" &>/dev/null
then
    printf "\n\e[31m%s\e[0m %s\n" "[Error]" \
        "Couldn't source '$PRETTY_OUTPUT_LIBRARY', this shouldn't happen. Stopping."
    exit 1
fi

BASE_PACKAGES=(
    zip unzip
    vim neovim
    lf bat fzf ripgrep
    wget build-essential age
)
setup_base_packages()
{
    if ! dpkg -s ${BASE_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        sudo apt-get install --yes ${BASE_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and install base packages nice to have on all machines: (${BASE_PACKAGES[*]})"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
remove_setup_base_packages()
{
    for package in ${BASE_PACKAGES[@]}
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


HOST_PACKAGES=(newsboat calcurse pass usbutils)
setup_host_packages()
{
    if ! dpkg -s ${HOST_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        sudo apt-get install --yes ${HOST_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and install packages used on my main machine: (${HOST_PACKAGES[*]})"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
remove_setup_host_packages()
{
    for package in ${HOST_PACKAGES[@]}
    do
        if dpkg -s $package &>/dev/null
        then
            sudo -v || return 1
            sudo remove --yes $package \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Uninstalling package: $package"
            [[ $? -ne 0 ]] && return 1
        fi
    done

    return 0
}


QEMU_PACKAGES=(
    virt-manager virt-viewer qemu-system qemu-system-gui qemu-utils swtpm
    spice-vdagent libvirt-daemon-system libvirt-clients dnsmasq
)
setup_qemu() 
{
    if ! dpkg -s ${QEMU_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        sudo apt-get install --yes ${QEMU_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Install qemu packages"
        [[ $? -ne 0 ]] && return 1
    else
        printf "\r\e[33m[skipping...]\e[0m %s\n" \
            "Qemu packages already installed"
    fi

    # Allows currently plugged in USB devices, so doesn't really make
    # sense to be in the setup
    #sudo chmod g+rwx -R /dev/bus/usb

    printf "\n\n\e[36m%s\e[0m\n\n" \
        "[!] Now you must run \`sudo usermod -aG libvirt \"username\"\`"

    return 0
}
remove_setup_qemu() 
{
    for package in ${QEMU_PACKAGES[@]}
    do
        if dpkg -s $package &>/dev/null
        then
            sudo -v || return 1
            sudo apt-get purge --yes $package \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Uninstalling package: $package"
            [[ $? -ne 0 ]] && return 1
        fi
    done

    return 0
}

setup_security()
{
    sudo -v || return 1

    if grep -e "^# deny = " -e "^deny = " /etc/security/faillock.conf &>/dev/null
    then
        sudo sed -i \
            -e '/^# deny =/c\deny = 6' \
            -e '/^deny =/c\deny = 6' \
            /etc/security/faillock.conf &>/dev/null \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Change max login attempts before lock out to 6 (3 isn't enough)"
        [[ $? -ne 0 ]] && return 1
    fi

    sudo passwd --lock root >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Disable root login"
    [[ $? -ne 0 ]] && return 1

    return 0
}
remove_setup_security()
{
    sudo -v || return 1

    if grep "^deny = 6" /etc/security/faillock.conf &>/dev/null
    then
        sudo sed -i '/^deny = 6/c\deny = 3' \
            /etc/security/faillock.conf &>/dev/null \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Change max login attempts before lock out back to 3"
        [[ $? -ne 0 ]] && return 1
    fi

    sudo passwd --unlock root >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Enable root login"
    [[ $? -ne 0 ]] && return 1

    return 0
}


setup_audio()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "The audio setup is not supported on your distro. Skipping."

    return 1
}
remove_setup_audio()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "The audio setup is not configured on your system. Skipping."

    return 1
}


setup_bluetooth()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "The bluetooth setup is not supported on your distro. Skipping."

    return 1
}
remove_setup_bluetooth()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "The bluetooth setup is not configured on your system. Skipping."

    return 1
}


MEDIA_PACKAGES=(ytfzf fzf mpv yt-dlp)
# Specifically for the yt-x script
MEDIA_PACKAGES+=(jq curl ffmpeg)
setup_media()
{
    if ! dpkg -s ${MEDIA_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        sudo apt-get install --yes ${MEDIA_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and install media packages"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
remove_setup_media()
{
    for package in ${MEDIA_PACKAGES[@]}
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


setup_gaming()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "The gaming setup is not supported on your distro. Skipping."

    return 1
}
remove_setup_gaming()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "The gaming setup is not configured on your system. Skipping."

    return 1
}


CARGO_PACKAGES=(probe-rs-tools elf2uf2-rs)
EMBEDDED_RUST_PACKAGES=(openocd)
setup_embedded_rust()
{
    if ! command -v cargo &>/dev/null
    then
        printf "\n\e[31m%s\e[0m\n" \
            "[!] cargo not installed, try installing rust first"
        return 1
    fi

    for cargo_package in ${CARGO_PACKAGES[@]}
    do
        cargo install $cargo_package \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and compile: '$cargo_package' with cargo"
        [[ $? -ne 0 ]] && return 1
    done


    if ! dpkg -s ${EMBEDDED_RUST_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        sudo apt-get install --yes ${EMBEDDED_RUST_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Install embedded rust packages"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
remove_setup_embedded_rust()
{
    local installed_cargo_packages="$(\
        cargo install --list | grep '^[a-z]' | awk '{print $1}'\
    )"

    for cargo_package in ${CARGO_PACKAGES[@]}
    do
        if echo "$installed_cargo_packages" \
            | grep "^$cargo_package$" &>/dev/null
        then
            cargo uninstall ${cargo_package[@]} \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Uninstall cargo package: '$cargo_package'"
            [[ $? -ne 0 ]] && return 1
        fi
    done

    for package in ${EMBEDDED_RUST_PACKAGES[@]}
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


setup_rust_dioxus()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "The dioxus setup is not supported on your distro. Skipping."

    return 1
}
remove_setup_rust_dioxus()
{
    printf "\n\e[33m%s\e[0m\n %s" "[Skipping]" \
        "The dioxus setup is not configured on your system. Skipping."

    return 1
}


THREE_D_PRINTING_PACKAGES=(freecad prusa-slicer)
setup_3d_printing()
{
    if ! dpkg -s ${THREE_D_PRINTING_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        sudo apt-get install --yes ${THREE_D_PRINTING_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Install CAD and Slicer tools"
        [[ $? -ne 0 ]] && exit 1
    fi

    return 0
}
remove_setup_3d_printing()
{
    for package in ${THREE_D_PRINTING_PACKAGES[@]}
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


GNOME_PACKAGES=(
    gdm3 gnome-backgrounds gnome-bluetooth-sendto gnome-control-center 
    gnome-keyring gnome-menus gnome-session gnome-settings-daemon 
    gnome-shell orca gnome-sushi adwaita-icon-theme glib-networking 
    gsettings-desktop-schemas evince gnome-calculator gnome-calendar
    gnome-terminal gnome-software gnome-text-editor gnome-snapshot
    tecla loupe nautilus totem simple-scan zenity evolution-data-server
    fonts-cantarell gstreamer1.0-packagekit gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good gvfs-backends gvfs-fuse libatk-adaptor
    libcanberra-pulse libglib2.0-bin libpam-gnome-keyring gir1.2-gnomedesktop-3.0
    pamixer brightnessctl
)
setup_gnome()
{
    if ! dpkg -s ${GNOME_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        sudo apt-get install --yes ${GNOME_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and install gnome packages"
        [[ $? -ne 0 ]] && return 1
    fi
    
    if ! systemctl is-enabled &>/dev/null
    then
        sudo -v || return 1
        sudo systemctl enable gdm \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Enable gdm"
    fi

    return 0
}
remove_setup_gnome()
{
    for package in ${GNOME_PACKAGES[@]}
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

    if systemctl is-enabled &>/dev/null
    then
        sudo -v || return 1
        sudo systemctl disable gdm \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Disable gdm"
    fi

    sed -i '/^source /etc/profile.d/vte.sh$/d' "${HOME}/.bashrc"

    return 0
}
