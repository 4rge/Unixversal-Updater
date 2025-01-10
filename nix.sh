#!/bin/sh

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Function to display messages with color coding 
msg() {
  echo -e "${!1}$2${RESET}"
}

# Display a banner
display_banner() {
  echo -e "${CYAN}=============================="
  echo -e "        SYSTEM UPDATER        "
  echo -e "=============================="
}

# Check necessary utilities
for cmd in lscpu awk grep lspci; do
  command -v "$cmd" >/dev/null || { msg RED "$cmd not installed. Exiting."; exit 1; }
done

# Check for virtualization
check_virtualization() {
  lspci | grep -qiE "Hypervisor|VirtualBox|VMware|QEMU|Parallels"
}

# Consolidated package manager and command mappings
declare -A pkg_info
pkg_info["ubuntu"]="apt"
pkg_info["debian"]="apt"
pkg_info["mint"]="apt"
pkg_info["kali"]="apt"
pkg_info["parrot"]="apt"
pkg_info["fedora"]="dnf"
pkg_info["rhel"]="dnf"
pkg_info["centos"]="dnf"
pkg_info["clearos"]="dnf"
pkg_info["arch"]="pacman"
pkg_info["manjaro"]="pacman"
pkg_info["arcolinux"]="pacman"
pkg_info["slackware"]="slackpkg"
pkg_info["salix"]="slackpkg"
pkg_info["alpine"]="apk"
pkg_info["freebsd"]="pkg"
pkg_info["openbsd"]="pkg_add"
pkg_info["netbsd"]="pkg_add"

# Update and upgrade commands mapping
declare -A update_commands
update_commands["apt"]="apt update"
update_commands["dnf"]="dnf makecache"
update_commands["pacman"]="pacman -Sy"
update_commands["slackpkg"]="slackpkg update"
update_commands["apk"]="apk update"
update_commands["pkg"]="pkg update"
update_commands["pkg_add"]="pkg_add -u"

declare -A upgrade_commands
upgrade_commands["apt"]="apt upgrade -y"
upgrade_commands["dnf"]="dnf upgrade -y"
upgrade_commands["pacman"]="pacman -Su --noconfirm"
upgrade_commands["slackpkg"]="slackpkg upgrade-all"
upgrade_commands["apk"]="apk upgrade"
upgrade_commands["pkg"]="pkg upgrade"

# Identify package manager
set_pkg_manager() {
  . /etc/os-release || { msg RED "Cannot detect distribution."; exit 1; }
  pkg_manager=${pkg_info[$ID]}
  [ -z "$pkg_manager" ] && { msg RED "Unsupported distribution: $ID."; exit 1; }
}

# Set update and upgrade commands
set_update_upgrade_cmds() {
  update_cmd=${update_commands[$pkg_manager]}
  upgrade_cmd=${upgrade_commands[$pkg_manager]}
}

# Update and upgrade packages
update_packages() {
  if eval "$update_cmd >/dev/null 2>&1"; then
    msg GREEN "Repositories updated successfully."
  else
    msg RED "Failed to update repositories."
    eval "$update_cmd"  # Show what went wrong
    return 1
  fi

  if [ "$#" -gt 0 ]; then
    additional_packages="$*"
    msg YELLOW "The following additional packages will be installed: $additional_packages"
    # Colorizing the question prompt
    read -p "$(echo -e "${CYAN}Do you want to install these packages? (y/n): ${RESET}") " answer
    [ "$answer" != "y" ] && { msg YELLOW "Skipping installation of additional packages."; return; }
    
    upgrade_cmd="$upgrade_cmd $additional_packages"
  fi

  if eval "$upgrade_cmd >/dev/null 2>&1"; then
    msg GREEN "Packages upgraded successfully."
  else
    msg RED "Failed to upgrade packages."
    eval "$upgrade_cmd"  # Show what went wrong
    return
  fi

  for pkg in $additional_packages; do
    check_cmd=$(case "$pkg_manager" in
      apt) echo "dpkg -l | grep -w $pkg" ;;
      dnf) echo "rpm -q $pkg" ;;
      pacman) echo "pacman -Qi $pkg" ;;
      slackpkg) echo "slackpkg search | grep -w $pkg" ;;
      apk) echo "apk info -e $pkg" ;;
      pkg|pkg_add) echo "pkg info | grep -w $pkg" ;;  # Using pkg for FreeBSD
    esac)

    if eval "$check_cmd >/dev/null 2>&1"; then
      msg GREEN "$pkg was installed successfully."
    else
      msg RED "Failed to install $pkg."
    fi
  done
}

# Check and install microcode for CPUs
install_microcode() {
  CPU_MODEL=$(lscpu | awk -F': ' '/Model name/{print $2}')
  
  # Determine the microcode package based on CPU type
  case "$CPU_MODEL" in 
    *Intel*) microcode_package="intel-ucode" ;; 
    *AMD*) microcode_package="amd-ucode" ;; 
    *) return ;; 
  esac

  # Check if the microcode package is already installed
  if eval "$pkg_manager -q $microcode_package >/dev/null 2>&1"; then
    msg GREEN "$microcode_package is already installed."

    # Check for the version of the installed microcode
    case "$pkg_manager" in
      apt)
        installed_version=$(dpkg -s "$microcode_package" | grep 'Version:' | awk '{print $2}')
        latest_version=$(apt-cache policy "$microcode_package" | grep 'Candidate:' | awk '{print $2}')
        ;;
      dnf|yum)
        installed_version=$(rpm -q "$microcode_package" --queryformat '%{VERSION}-%{RELEASE}\n')
        latest_version=$(dnf info "$microcode_package" | grep 'Version' | awk '{print $3}')
        ;;
      pacman)
        installed_version=$(pacman -Qi "$microcode_package" | grep 'Version' | awk '{print $3}')
        latest_version=$(pacman -Si "$microcode_package" | grep 'Version' | awk '{print $3}')
        ;;
      *)
        msg RED "Unable to determine version information for package manager: $pkg_manager."
        return
        ;;
    esac

    if [ "$installed_version" != "$latest_version" ]; then
      msg YELLOW "Update available for $microcode_package: $installed_version -> $latest_version."
      # Colorizing the question prompt
      read -p "$(echo -e "${CYAN}Do you want to update $microcode_package? (y/n): ${RESET}") " answer
      if [ "$answer" = "y" ]; then
        install_cmd="sudo $pkg_manager ${pkg_manager:+-S} $microcode_package"
        if eval "$install_cmd"; then 
          msg GREEN "Microcode updated successfully for $CPU_MODEL."; 
        else 
          msg RED "Failed to update microcode for $CPU_MODEL."; 
        fi
      else
        msg YELLOW "Skipping microcode update for $CPU_MODEL."
      fi
    else
      msg GREEN "$microcode_package is already up to date."
    fi
  else
    # Colorizing the question prompt
    read -p "$(echo -e "${CYAN}Do you want to install $microcode_package? (y/n): ${RESET}") " answer
    if [ "$answer" = "y" ]; then
      install_cmd="sudo $pkg_manager ${pkg_manager:+-S} $microcode_package"
      if eval "$install_cmd"; then 
        msg GREEN "Microcode installed successfully for $CPU_MODEL."; 
      else 
        msg RED "Failed to install microcode for $CPU_MODEL."; 
      fi
    else
      msg YELLOW "Skipping installation of microcode for $CPU_MODEL."
    fi
  fi
}

# Identify GPU
identify_gpu() {
  GPU_MODEL=$(lspci | grep -i vga | awk -F ': ' '{print $2}')
  [ -n "$GPU_MODEL" ] && msg GREEN "Detected GPU: $GPU_MODEL." || msg RED "No GPU detected."
}

# Main function
main() {
  display_banner
  check_virtualization && (msg YELLOW "Running upgrades only due to virtualization.") || msg CYAN "Running full update process."
  set_pkg_manager
  set_update_upgrade_cmds
  update_packages "$@"
  install_microcode
  identify_gpu
  msg GREEN "Update complete."
}

main "$@"
