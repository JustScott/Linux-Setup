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

PROJECT_NAME="Linux-Setup"
SCRIPT_NAME="please"

PRETTY_OUTPUT_LIBRARY="./GeneralLibraries/pretty_output_library.sh"

SSH_CONFIG_FILE_PATH="/etc/ssh/sshd_config.d/99‑disable‑root.conf"

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
    wget base-devel age
)
setup_base_packages()
{
    if ! pacman -Q ${BASE_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        sudo pacman -Sy --noconfirm ${BASE_PACKAGES[@]} \
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


HOST_PACKAGES=(newsboat calcurse pass usbutils)
setup_host_packages()
{
    if ! pacman -Q ${HOST_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        sudo pacman -Sy --noconfirm ${HOST_PACKAGES[@]} \
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


QEMU_PACKAGES=(
    gnome-boxes virt-manager virt-viewer \
    qemu-emulators-full spice-vdagent swtpm \
)
setup_qemu() 
{
    if ! pacman -Q ${QEMU_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm ${QEMU_PACKAGES[@]} \
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

    CURRENT_USER=$USER

    {
        if ! cat /etc/libvirt/libvirtd.conf \
            | grep 'unix_sock_group = libvirt' &>/dev/null
        then
            sudo bash -c 'echo -e "\nunix_sock_group = libvirt" >> /etc/libvirt/libvirtd.conf'
        fi
        if ! cat /etc/libvirt/libvirtd.conf \
            | grep 'unix_sock_rw_perms = 0770' &>/dev/null
        then
            sudo bash -c 'echo "unix_sock_rw_perms = 0770" >> /etc/libvirt/libvirtd.conf'
        fi
        if ! cat /etc/libvirt/qemu.conf | grep "group=$CURRENT_USER" &>/dev/null
        then
            sudo bash -c "echo 'group=$CURRENT_USER' >> /etc/libvirt/qemu.conf"
        fi
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Alter config files"
    [[ $? -ne 0 ]] && return 1

    if ! groups | grep "libvirt" &>/dev/null
    then
        sudo usermod -aG libvirt $CURRENT_USER \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Add '$CURRENT_USER' to 'libvirt' group"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
remove_setup_qemu() 
{
    for package in ${QEMU_PACKAGES[@]}
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

    if ! groups | grep "libvirt" &>/dev/null
    then
        sudo gpasswd -d $CURRENT_USER libvirt \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Remove '$CURRENT_USER' from the 'libvirt' group"
        [[ $? -ne 0 ]] && return 1
    fi

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

    if ! [[ -f "$SSH_CONFIG_FILE_PATH" ]]
    then
        sudo bash -c \
            "echo 'PermitRootLogin no' >> "$SSH_CONFIG_FILE_PATH"" \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Add rule to disable root login over ssh"
        [[ $? -ne 0 ]] && return 1

        if systemctl is-active sshd &>/dev/null
        then
            sudo systemctl reload sshd \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Reload the ssh daemon"
            [[ $? -ne 0 ]] && return 1
        fi
    fi

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

    if [[ -f "$SSH_CONFIG_FILE_PATH" ]]
    then
        sudo rm $SSH_CONFIG_FILE_PATH &>/dev/null
        task_output $! "$STDERR_LOG_PATH" \
            "Remove rule against root login over ssh"
        [[ $? -ne 0 ]] && return 1

        if systemctl is-active sshd &>/dev/null
        then
            sudo systemctl reload sshd \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Reload the ssh daemon"
            [[ $? -ne 0 ]] && return 1
        fi
    fi

    return 0
}

AUDIO_PACKAGES=(
    pipewire pipewire-alsa pipewire-audio pipewire-jack \
    pipewire-pulse pavucontrol pamixer \
)
setup_audio()
{
    if pacman -Q pulseaudio &>/dev/null; then
        if systemctl --user is-active --quiet pulseaudio &>/dev/null
        then
            systemctl --user disable --now pulseaudio &>/dev/null
            task_output $! "$STDERR_LOG_PATH" \
                "Disable and stop pulseaudio service"
        fi

        sudo -v || return 1
        yes | sudo pacman -R pulseaudio \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Remove pulseaudio"
        [[ $? -ne 0 ]] && return 1
    fi

    if ! pacman -Q ${AUDIO_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        yes | sudo pacman -Sy ${AUDIO_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and install pipewire audio packages with pacman"
        [[ $? -ne 0 ]] && return 1
    fi

    if ! systemctl --user is-enabled pipewire &>/dev/null
    then
        systemctl --user enable pipewire \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Enable the pipewire services"
        [[ $? -ne 0 ]] && return 1
    fi

    if ! systemctl --user is-active pipewire &>/dev/null
    then
        systemctl --user start pipewire \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Start pipewire services"
        [[ $? -ne 0 ]] && return 1
    fi

    if ! systemctl --user is-enabled pipewire-pulse &>/dev/null
    then
        systemctl --user enable pipewire-pulse \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Enable the pipewire-pulse services"
        [[ $? -ne 0 ]] && return 1
    fi

    if ! systemctl --user is-active pipewire-pulse &>/dev/null
    then
        systemctl --user start pipewire-pulse \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Start the pipewire-pulse services"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
remove_setup_audio()
{
    if pacman -Q pulseaudio &>/dev/null; then
        if systemctl --user is-active --quiet pulseaudio &>/dev/null
        then
            systemctl --user disable --now pulseaudio &>/dev/null
            task_output $! "$STDERR_LOG_PATH" \
                "Disable and stop pulseaudio service"
        fi

        sudo -v || return 1
        yes | sudo pacman -Rs pulseaudio \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Remove pulseaudio"
        [[ $? -ne 0 ]] && return 1
    fi

    for package in ${AUDIO_PACKAGES[@]}
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

    if systemctl --user is-enabled pipewire &>/dev/null
    then
        systemctl --user disable pipewire \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Disable the pipewire services"
        [[ $? -ne 0 ]] && return 1
    fi

    if systemctl --user is-active pipewire &>/dev/null
    then
        systemctl --user stop pipewire \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Stop pipewire services"
        [[ $? -ne 0 ]] && return 1
    fi

    if systemctl --user is-enabled pipewire-pulse &>/dev/null
    then
        systemctl --user disable pipewire-pulse \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Disable the pipewire-pulse services"
        [[ $? -ne 0 ]] && return 1
    fi

    if systemctl --user is-active pipewire-pulse &>/dev/null
    then
        systemctl --user stop pipewire-pulse \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Stop the pipewire-pulse services"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}


BLUETOOTH_PACKAGES=(bluez bluez-utils)
setup_bluetooth()
{
    if ! pacman -Q ${BLUETOOTH_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm ${BLUETOOTH_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and install bluetooth packages with pacman"
        [[ $? -ne 0 ]] && return 1
    fi

    if ! systemctl is-enabled bluetooth &>/dev/null
    then
        sudo -v || return 1
        sudo systemctl enable bluetooth \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Enable bluetooth"
        [[ $? -ne 0 ]] && return 1
    fi

    if ! systemctl is-active bluetooth &>/dev/null
    then
        sudo -v || return 1
        sudo systemctl start bluetooth \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Start bluetooth service"
        [[ $? -ne 0 ]] && return 1
    fi

    if sudo rfkill list bluetooth | grep "Soft blocked: yes" &>/dev/null
    then
        sudo -v || return 1
        sudo rfkill unblock bluetooth >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Remove bluetooth soft block"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
remove_setup_bluetooth()
{
    if systemctl is-active bluetooth &>/dev/null
    then
        sudo -v || return 1
        sudo systemctl stop bluetooth \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Stop bluetooth service"
        [[ $? -ne 0 ]] && return 1
    fi

    if systemctl is-enabled bluetooth &>/dev/null
    then
        sudo -v || return 1
        sudo systemctl disable bluetooth \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" "Disable bluetooth service"
        [[ $? -ne 0 ]] && return 1
    fi

    for package in ${BLUETOOTH_PACKAGES[@]}
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


MEDIA_PACKAGES=(ytfzf fzf mpv yt-dlp)
# Specifically for the yt-x script
MEDIA_PACKAGES+=(jq curl ffmpeg)
setup_media()
{
    if ! pacman -Q ${MEDIA_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm ${MEDIA_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and install media packages with pacman"
        [[ $? -ne 0 ]] && return 1
    fi

    return 0
}
remove_setup_media()
{
    for package in ${MEDIA_PACKAGES[@]}
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

GAMING_PACKAGES=( btop rocm-smi-lib )
setup_gaming()
{
    local REQUIRED_PACKAGES=( flatpak )
    GAMING_PACKAGES+=(${REQUIRED_PACKAGES[@]})
    local FLATPAK_PACKAGES=( com.github.tchx84.Flatseal com.valvesoftware.Steam )

    if groups | grep -E "(sudo|wheel)" &>/dev/null
    then
        sudo -v || return 1
        if ! pacman -Q ${GAMING_PACKAGES[@]} &>/dev/null; then
            yes | sudo pacman -Sy --noconfirm ${GAMING_PACKAGES[@]} \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Download gaming related packages"
            [[ $? -ne 0 ]] && return 1
        else
            printf "\r\e[34m[Skipping]\e[0m %s\n" \
                "Gaming related packages and Flatpak already installed"
        fi
    fi
    if pacman -Q ${REQUIRED_PACKAGES[@]} &>/dev/null
    then
        flatpak remote-add --if-not-exists --user flathub \
            https://flathub.org/repo/flathub.flatpakrepo \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Add remote source 'flathub' to flatpak"
        [[ $? -ne 0 ]] && return 1

        flatpak install --noninteractive --or-update \
            --user -y ${FLATPAK_PACKAGES[@]} \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Install or update GUI apps with flatpak"
        [[ $? -ne 0 ]] && return 1

        flatpak override --user --device=dri com.valvesoftware.Steam
        task_output $! "$STDERR_LOG_PATH" \
            "Enable GPU acceleration for Steam"
        [[ $? -ne 0 ]] && return 1

        {
            for flatpak in ${FLATPAK_PACKAGES[@]} 
            do 
                flatpak_name=$(echo $flatpak | awk -F'.' '{print $NF}' \
                    | tr '[:upper:]' '[:lower:]')

                bashrc_line="alias $flatpak_name=\"\$HOME/.local/share/flatpak/exports/bin/${flatpak}\""
 
                if ! grep "$bashrc_line" "${HOME}/.bashrc" &>/dev/null 
                then
                    echo "$bashrc_line" >> "${HOME}/.bashrc"
                fi
            done
        } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Add an alias for each flatpak app to .bashrc"
        [[ $? -ne 0 ]] && return 1
    else
        printf "\r\e[31m%s\e[0m\n" \
            "[!] Must install flatpak with pacman"
        return 1
    fi

    # Nvidia laptops
    #AUR_PACKAGES+=(optimus-manager-git libgdm-prime gdm-prime)
    #optimus-manager --switch nvidia --noconfirm

    # Mod manager for lethal company
    #AUR_PACKAGES+=( r2modman-bin )
    #
    # Edit /usr/share/applications/r2modman.desktop, adding --no-sandbox to
    #  the exec command, before the %U
    #

    return 0
}
remove_setup_gaming()
{
    # Not removing flatpak as it could be used by the user
    for package in ${GAMING_PACKAGES[@]}
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


CARGO_PACKAGES=(probe-rs-tools elf2uf2-rs)
EMBEDDED_RUST_PACKAGES=(openocd)
setup_embedded_rust()
{
    if ! command -v cargo &>/dev/null
    then
        printf "\n\e[31m%s\e[0m\n" \
            "[!] cargo not installed, try running \`please install rust\` first"
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


    if ! pacman -Q ${EMBEDDED_RUST_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        yes | sudo pacman -Sy ${EMBEDDED_RUST_PACKAGES[@]} --noconfirm \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Install embedded rust packages with pacman"
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

unset CARGO_PACKAGES
CARGO_PACKAGES=(dioxus-cli)
DIOXUS_AUR_PACKAGES=(
    android-ndk android-sdk android-sdk-build-tools
    android-sdk-cmdline-tools-latest android-sdk-platform-tools
    android-tools android-platform android-emulator
    jdk21-openjdk webkit2gtk-4.1 base-devel curl wget
    file openssl appmenu-gtk-module libappindicator
    librsvg xdotool libbsd
)
setup_rust_dioxus()
{
    if ! command -v cargo &>/dev/null
    then
        printf "\n\e[31m%s\e[0m\n" \
            "[!] cargo not installed, try running \`please install rust\` first"
        return 1
    fi

    if ! command -v yay &>/dev/null
    then
        printf "\n\e[31m%s\e[0m\n" \
            "[!] yay not installed, try running \`please install yay\` first"
        return 1
    fi

    for package in ${DIOXUS_AUR_PACKAGES[@]}
    do
        if ! yay -Q $package &>/dev/null; then
            sudo -v || return 1
            yes | yay -S $package --noconfirm \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" \
                "Download and install: '$package' from the AUR"
            [[ $? -ne 0 ]] && return 1
        fi
    done

    for cargo_package in ${CARGO_PACKAGES[@]}
    do
        cargo install $cargo_package \
            >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
        task_output $! "$STDERR_LOG_PATH" \
            "Download and compile: '$cargo_package' with cargo"
        [[ $? -ne 0 ]] && return 1
    done

    {
        if ! cat "${HOME}/.bashrc" \
            | grep "ANDROID_NDK_HOME=/opt/android-ndk$" &>/dev/null
        then
            echo "export ANDROID_NDK_HOME=/opt/android-ndk" >> "${HOME}/.bashrc"
        fi

        if ! cat "${HOME}/.bashrc" \
            | grep "ANDROID_HOME=/opt/android-sdk$" &>/dev/null
        then
            echo "export ANDROID_HOME=/opt/android-sdk" >> "${HOME}/.bashrc"
        fi

        if ! cat "${HOME}/.bashrc" \
            | grep "JAVA_HOME=/usr/lib/jvm/java-21-openjdk$" &>/dev/null
        then
            echo "export JAVA_HOME=/usr/lib/jvm/java-21-openjdk" \
                >> "${HOME}/.bashrc"
        fi

        if ! cat "${HOME}/.bashrc" \
            | grep "PATH=\$PATH:\$ANDROID_HOME/tools$" &>/dev/null
        then
            echo "export PATH=\$PATH:\$ANDROID_HOME/tools" \
                >> "${HOME}/.bashrc"
        fi

        if ! cat "${HOME}/.bashrc" \
            | grep "PATH=\$PATH:\$ANDROID_HOME/platform-tools$" \
            &>/dev/null
        then
            echo "export PATH=\$PATH:\$ANDROID_HOME/platform-tools" \
                >> "${HOME}/.bashrc"
        fi

        if ! cat "${HOME}/.bashrc" \
            | grep "PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin$" \
            &>/dev/null
        then
            echo "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin" \
                >> "${HOME}/.bashrc"
        fi

        if ! cat "${HOME}/.bashrc" \
            | grep "PATH=\$PATH:\$JAVA_HOME/bin$" &>/dev/null
        then
            echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> "${HOME}/.bashrc"
        fi
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" \
        "Add the android-sdk to PATH in .bashrc"
    [[ $? -ne 0 ]] && return 1

    rustup target add \
        aarch64-linux-android armv7-linux-androideabi \
        i686-linux-android x86_64-linux-android \
        >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Add android build targets with rustup"
    [[ $? -ne 0 ]] && return 1

    {
        sudo groupadd android-sdk
        sudo gpasswd -a $USER android-sdk
        sudo chown -R :android-sdk /opt/android-sdk
        sudo chmod -R g+rwx /opt/android-sdk
    #    sudo setfacl -R -m g:android-sdk:rwx /opt/android-sdk
    #    sudo setfacl -d -m g:android-sdk:rwX /opt/android-sdk
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" \
        "Create android-sdk group and add '$USER' to it"
    [[ $? -ne 0 ]] && return 1

newgrp android-sdk <<EOF
cd $linux_setup_directory

if ! [[ -f "./$PRETTY_OUTPUT_LIBRARY" ]]
then
    printf "\n\e[31m%s\e[0m\n" \
        "[!] Cannot source library file, have you ran \`please add-to-path\`?"
    exit 1
fi

source ./$PRETTY_OUTPUT_LIBRARY

yes | sdkmanager --licenses \
    >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
task_output $! "$STDERR_LOG_PATH" "Accept Android SDK Licenses"
[[ $? -ne 0 ]] && exit 1

{
    yes | sdkmanager "system-images;android-30;default;x86_64"
    sdkmanager "emulator"
} >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
task_output $! "$STDERR_LOG_PATH" \
    "Install & Set-up emulator with qemu"
[[ $? -ne 0 ]] && exit 1

sudo archlinux-java set java-21-openjdk \
    >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
task_output $! "$STDERR_LOG_PATH" \
    "Set system java version to java-21-openjdk"
[[ $? -ne 0 ]] && exit 1
EOF

    # avdmanager create avd -n new_avd -k "system-images;android-30;default;x86_64"
    # emulator -avd new_avd

    return 0
}
remove_setup_rust_dioxus()
{
    if ! command -v cargo &>/dev/null
    then
        printf "\n\e[31m%s\e[0m\n" \
            "[!] cargo not installed, try running \`please install rust\` first"
        return 1
    fi

    if ! command -v yay &>/dev/null
    then
        printf "\n\e[31m%s\e[0m\n" \
            "[!] yay not installed, try running \`please install yay\` first"
        return 1
    fi

    local installed_cargo_packages="$(\
        cargo install --list | grep '^[a-z]' | awk '{print $1}'\
    )"

    sudo -v || return 1

    sudo gpasswd -d $USER android-sdk &>/dev/null;sleep 1;true &
    task_output $! "$STDERR_LOG_PATH" \
        "Remove '$USER' from the 'android-sdk' group"

    sudo groupdel android-sdk &>/dev/null;sleep 1;true &
    task_output $! "$STDERR_LOG_PATH" "Delete the 'android-sdk' group"

    rustup target remove aarch64-linux-android &>/dev/null
    rustup target remove armv7-linux-androideabi &>/dev/null
    rustup target remove i686-linux-android &>/dev/null
    rustup target remove x86_64-linux-android &>/dev/null

    sleep 1;true &
    task_output $! "$STDERR_LOG_PATH" "Remove android rustup targets"

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

    for package in ${DIOXUS_AUR_PACKAGES[@]}
    do
        if yay -Q $package &>/dev/null
        then
            sudo -v || return 1
            yes | yay -Rs --noconfirm $package \
                >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
            task_output $! "$STDERR_LOG_PATH" "Uninstalling package: $package"
            [[ $? -ne 0 ]] && return 1
        fi
    done

    {
        sed -i '/^export ANDROID_NDK_HOME=\/opt\/android-ndk$/d' \
            "${HOME}/.bashrc"
        sed -i '/^export ANDROID_HOME=\/opt\/android-sdk$/d' \
            "${HOME}/.bashrc"
        sed -i '/^export JAVA_HOME=\/usr\/lib\/jvm\/java-21-openjdk$/d' \
            "${HOME}/.bashrc"
        sed -i '/^export PATH=$PATH:$ANDROID_HOME\/tools$/d' \
            "${HOME}/.bashrc"
        sed -i '/^export PATH=$PATH:$ANDROID_HOME\/platform-tools$/d' \
            "${HOME}/.bashrc"
        sed -i \
            '/^export PATH=$PATH:$ANDROID_HOME\/cmdline-tools\/latest\/bin$/d' \
            "${HOME}/.bashrc"
        sed -i '/^export PATH=$PATH:$JAVA_HOME\/bin$/d' \
            "${HOME}/.bashrc"
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" \
        "Remove android-sdk from PATH in .bashrc"
    [[ $? -ne 0 ]] && return 1

    return 0
}


THREE_D_PRINTING_PACKAGES=(freecad prusa-slicer)
setup_3d_printing()
{
    if ! pacman -Q ${THREE_D_PRINTING_PACKAGES[@]} &>/dev/null; then
        sudo -v || return 1
        yes | sudo pacman -Sy --noconfirm ${THREE_D_PRINTING_PACKAGES[@]} \
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

GNOME_PACKAGES=(
    gdm loupe papers sushi evince gvfs mutter nautilus pamixer brightnessctl
    gnome-color-manager gnome-control-center gnome-menus gnome-session
    gnome-bluetooth-3.0 gnome-settings-daemon gnome-shell gnome-software
    gnome-terminal gnome-keyring gnome-backgrounds gnome-calculator
    xdg-desktop-portal-gnome xdg-user-dirs power-profiles-daemon wl-clipboard
    noto-fonts adwaita-fonts gnu-free-fonts noto-fonts noto-fonts-extra
)
setup_gnome()
{
    if ! pacman -Q ${GNOME_PACKAGES[@]} &>/dev/null
    then
        sudo -v || return 1
        sudo pacman -Sy --noconfirm ${GNOME_PACKAGES[@]} \
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
        if pacman -Q $package &>/dev/null
        then
            sudo -v || return 1
            yes | sudo pacman -Rs --noconfirm $package \
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
