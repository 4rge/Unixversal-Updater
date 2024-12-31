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
  echo -e "${GREEN}Success: completed operations"
  echo -e "${RED}Error: something went wrong"
  echo -e "${YELLOW}Warning: potential issues"
  echo -e "${CYAN}Info: additional context"
}

# Check necessary utilities
for cmd in lscpu awk grep lspci; do
  command -v "$cmd" >/dev/null || { msg RED "$cmd not installed. Exiting."; exit 1; }
done

# Check for virtualization
check_virtualization() {
  lspci | grep -qiE "Hypervisor|VirtualBox|VMware|QEMU|Parallels"
}

# Identify package manager
set_pkg_manager() {
  . /etc/os-release || { msg RED "Cannot detect distribution."; exit 1; }
  case "$ID" in
    ubuntu|debian|mint|kali|parrot) pkg_manager="apt" ;;
    fedora|rhel|centos|clearos) pkg_manager="dnf" ;;
    arch|manjaro|arcolinux) pkg_manager="pacman" ;;
    slackware|salix) pkg_manager="slackpkg" ;;
    alpine) pkg_manager="apk" ;;
    freebsd|openbsd|netbsd) pkg_manager="pkg_add" ;;
    *) msg RED "Unsupported distribution: $ID."; exit 1 ;;
  esac
}

# Set update and upgrade commands
set_update_upgrade_cmds() {
  case "$pkg_manager" in
    apt) update_cmd="apt update"; upgrade_cmd="apt upgrade -y" ;;
    dnf|yum) update_cmd="$pkg_manager makecache"; upgrade_cmd="$pkg_manager upgrade -y" ;;
    pacman) update_cmd="pacman -Sy"; upgrade_cmd="pacman -Su --noconfirm" ;;
    slackpkg) update_cmd="slackpkg update"; upgrade_cmd="slackpkg upgrade-all" ;;
    apk) update_cmd="apk update"; upgrade_cmd="apk upgrade" ;;
    pkg_add) update_cmd="pkg update"; upgrade_cmd="pkg upgrade" ;;
  esac
}

# Update and upgrade packages
update_packages() {
  eval "$update_cmd >/dev/null 2>&1" && msg GREEN "Repositories updated successfully." || msg RED "Failed to update repositories."
  eval "$upgrade_cmd >/dev/null 2>&1" && msg GREEN "Packages upgraded successfully." || msg RED "Failed to upgrade packages."
}

# Check and install microcode for CPUs
install_microcode() {
  CPU_MODEL=$(lscpu | awk -F': ' '/Model name/{print $2}')
  
  # Determine the microcode package based on CPU type
  microcode_package=$(case "$CPU_MODEL" in 
                        *Intel*) echo "intel-ucode" ;; 
                        *AMD*) echo "amd-ucode" ;; 
                        *) return ;; 
                      esac)

  # Check if the microcode package is already installed
  if eval "$pkg_manager -q $microcode_package >/dev/null 2>&1"; then
    msg GREEN "$microcode_package is already installed."

    # Check for the version of the installed microcode
    if [ "$pkg_manager" = "apt" ]; then
      installed_version=$(dpkg -s "$microcode_package" | grep 'Version:' | awk '{print $2}')
      latest_version=$(apt-cache policy "$microcode_package" | grep 'Candidate:' | awk '{print $2}')
    elif [ "$pkg_manager" = "dnf" ] || [ "$pkg_manager" = "yum" ]; then
      installed_version=$(rpm -q "$microcode_package" --queryformat '%{VERSION}-%{RELEASE}\n')
      latest_version=$(dnf info "$microcode_package" | grep 'Version' | awk '{print $3}')
    elif [ "$pkg_manager" = "pacman" ]; then
      installed_version=$(pacman -Qi "$microcode_package" | grep 'Version' | awk '{print $3}')
      latest_version=$(pacman -Si "$microcode_package" | grep 'Version' | awk '{print $3}')
    else
      msg RED "Unable to determine version information for package manager: $pkg_manager."
      return
    fi

    if [ "$installed_version" != "$latest_version" ]; then
      msg YELLOW "Update available for $microcode_package: $installed_version -> $latest_version."
      read -p "Do you want to update $microcode_package? (y/n): " answer
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
    read -p "Do you want to install $microcode_package? (y/n): " answer
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
  if [ -n "$GPU_MODEL" ]; then
    msg GREEN "Detected GPU: $GPU_MODEL"
  else
    msg RED "No GPU detected."
  fi
}

# Main function
main() {
  display_banner
  check_virtualization && (msg YELLOW "Running upgrades only due to virtualization.") || msg CYAN "Running full update process."
  set_pkg_manager
  set_update_upgrade_cmds
  update_packages
  install_microcode
  identify_gpu
  msg GREEN "Update complete."
}

main "$@"
