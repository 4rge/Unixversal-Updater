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
pkg_info=( ["ubuntu"]="apt" ["debian"]="apt" ["mint"]="apt" ["kali"]="apt" ["parrot"]="apt"
            ["fedora"]="dnf" ["rhel"]="dnf" ["centos"]="dnf" ["clearos"]="dnf"
            ["arch"]="pacman" ["manjaro"]="pacman" ["arcolinux"]="pacman"
            ["slackware"]="slackpkg" ["salix"]="slackpkg" ["alpine"]="apk"
            ["freebsd"]="pkg" ["openbsd"]="pkg_add" ["netbsd"]="pkg_add" )

# Update and upgrade commands mapping
declare -A update_commands
update_commands=( ["apt"]="apt update" ["dnf"]="dnf makecache" ["pacman"]="pacman -Sy"
                  ["slackpkg"]="slackpkg update" ["apk"]="apk update" ["pkg"]="pkg update"
                  ["pkg_add"]="pkg_add -u" )

declare -A upgrade_commands
upgrade_commands=( ["apt"]="apt upgrade -y" ["dnf"]="dnf upgrade -y" ["pacman"]="pacman -Su --noconfirm"
                   ["slackpkg"]="slackpkg upgrade-all" ["apk"]="apk upgrade" ["pkg"]="pkg upgrade" )

# CPU Microcode Packages mapping
declare -A microcode_packages
microcode_packages=( ["Intel"]="intel-ucode" ["AMD"]="amd-ucode" )

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

# Ensure the utility for checking installation
is_installed() {
  local pkg_name="$1"
  case "$pkg_manager" in
    apt) dpkg -l | grep -qw "$pkg_name" && return 0 || return 1 ;;
    dnf) rpm -q "$pkg_name" >/dev/null && return 0 || return 1 ;;
    pacman) pacman -Qi "$pkg_name" >/dev/null && return 0 || return 1 ;;
    slackpkg) slackpkg search | grep -qw "$pkg_name" && return 0 || return 1 ;;
    apk) apk info -e "$pkg_name" >/dev/null && return 0 || return 1 ;;
    pkg|pkg_add) pkg info | grep -qw "$pkg_name" && return 0 || return 1 ;;
    *) msg RED "Unsupported package manager: $pkg_manager." && return 1 ;;
  esac
}

# Get installed and latest package versions
get_package_version() {
  local pkg_name="$1"
  local installed_version
  local latest_version

  case "$pkg_manager" in
    apt)
      installed_version=$(dpkg -s "$pkg_name" | grep 'Version:' | awk '{print $2}')
      latest_version=$(apt-cache policy "$pkg_name" | grep 'Candidate:' | awk '{print $2}')
      ;;
    dnf)
      installed_version=$(rpm -q "$pkg_name" --queryformat '%{VERSION}-%{RELEASE}\n')
      latest_version=$(dnf info "$pkg_name" | grep 'Version' | awk '{print $3}')
      ;;
    pacman)
      installed_version=$(pacman -Qi "$pkg_name" | grep 'Version' | awk '{print $3}')
      latest_version=$(pacman -Si "$pkg_name" | grep 'Version' | awk '{print $3}')
      ;;
    slackpkg)
      installed_version=$(slackpkg search | grep -w "$pkg_name" | awk '{print $2}')
      latest_version=${installed_version}  # Placeholder, slackpkg doesn't handle this well
      ;;
    apk)
      installed_version=$(apk info -v "$pkg_name")
      latest_version=$(apk search -v "$pkg_name" | head -n1 | awk '{print $2}')
      ;;
    pkg|pkg_add)
      installed_version=$(pkg info "$pkg_name" | awk -F ' ' '{print $2}')
      latest_version=$(pkg search -e "$pkg_name" | awk -F ' ' '{print $2}')
      ;;
    *)
      msg RED "Unable to determine version information for package manager: $pkg_manager."
      return 1
      ;;
  esac

  echo "$installed_version" "$latest_version"
}

# Update and upgrade packages
update_packages() {
  eval "$update_cmd >/dev/null 2>&1" && msg GREEN "Repositories updated successfully." || {
    msg RED "Failed to update repositories."
    eval "$update_cmd"  # Show what went wrong
    return 1
  }

  if [ "$#" -gt 0 ]; then
    additional_packages="$*"
    msg YELLOW "The following additional packages will be installed: $additional_packages"
    read -p "$(echo -e "${CYAN}Do you want to install these packages? (y/n): ${RESET}") " answer
    [ "$answer" != "y" ] && { msg YELLOW "Skipping installation of additional packages."; return; }
    
    upgrade_cmd="$upgrade_cmd $additional_packages"
  fi

  eval "$upgrade_cmd >/dev/null 2>&1" && msg GREEN "Packages upgraded successfully." || {
    msg RED "Failed to upgrade packages."
    eval "$upgrade_cmd"  # Show what went wrong
    return
  }

  for pkg in $additional_packages; do
    is_installed "$pkg" && {
      read installed_version latest_version < <(get_package_version "$pkg")
      msg GREEN "$pkg was installed successfully (version: $installed_version)."
    } || msg RED "Failed to install $pkg."
  done
}

# Check and install microcode for CPUs
install_microcode() {
  CPU_MODEL=$(lscpu | awk -F': ' '/Model name/{print $2}')

  for key in "${!microcode_packages[@]}"; do
    echo "$CPU_MODEL" | grep -qi "$key" && {
      microcode_package="${microcode_packages[$key]}"
      break
    }
  done

  [ -z "$microcode_package" ] && return 

  is_installed "$microcode_package" && {
    msg GREEN "$microcode_package is already installed."
    read installed_version latest_version < <(get_package_version "$microcode_package")
    [ "$installed_version" != "$latest_version" ] && {
      msg YELLOW "Update available for $microcode_package: $installed_version -> $latest_version."
      read -p "$(echo -e "${CYAN}Do you want to update $microcode_package? (y/n): ${RESET}") " answer
      [ "$answer" = "y" ] && {
        install_cmd="sudo $pkg_manager ${pkg_manager:+-S} $microcode_package"
        eval "$install_cmd" && msg GREEN "Microcode updated successfully for $CPU_MODEL." || msg RED "Failed to update microcode for $CPU_MODEL."
      } || msg YELLOW "Skipping microcode update for $CPU_MODEL."
    } || msg GREEN "$microcode_package is already up to date."
  } || {
    read -p "$(echo -e "${CYAN}Do you want to install $microcode_package? (y/n): ${RESET}") " answer
    [ "$answer" = "y" ] && {
      install_cmd="sudo $pkg_manager ${pkg_manager:+-S} $microcode_package"
      eval "$install_cmd" && msg GREEN "Microcode installed successfully for $CPU_MODEL." || msg RED "Failed to install microcode for $CPU_MODEL."
    } || msg YELLOW "Skipping installation of microcode for $CPU_MODEL."
  }
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
