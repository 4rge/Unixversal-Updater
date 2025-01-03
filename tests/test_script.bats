#!/bin/sh
msg() { 
  echo "$2"; 
}

lscpu() {
  echo 'Model name: Intel Xeon'
}

lspci() {
  echo '01:00.0 VGA compatible controller: Intel Corporation'
}

command() {
  return 0
}

ID=ubuntu

check_virtualization() {
  return 0
}

set_pkg_manager() {
  pkg_manager='apt'
  echo "DEBUG: pkg_manager set to: $pkg_manager"
}

set_update_upgrade_cmds() {
  update_cmd='echo apt update'
  upgrade_cmd='echo apt upgrade -y'
}

update_packages() { 
  eval "$update_cmd" && msg 2 'Repositories updated successfully.' || msg 1 'Failed to update repositories.'; 
  eval "$upgrade_cmd" && msg 2 'Packages upgraded successfully.' || msg 1 'Failed to upgrade packages.'; 
}

install_microcode() { 
  msg 2 'Microcode installed successfully for Intel Xeon.'; 
}

identify_gpu() { 
  msg 1 'No GPU detected.'; 
}
