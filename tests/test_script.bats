#!/usr/bin/env bats

setup() {
  echo "#!/bin/sh" > /tmp/script.sh
  echo "msg() { echo -e \"\$(tput setaf \$1)\$2\$(tput sgr0)\"; }" >> /tmp/script.sh
  echo "lscpu() { echo 'Model name: Intel Xeon'; }" >> /tmp/script.sh
  echo "lspci() { echo '01:00.0 VGA compatible controller: Intel Corporation'; }" >> /tmp/script.sh
  
  echo "command() { return 0; }" >> /tmp/script.sh
  echo "ID=ubuntu" >> /tmp/script.sh
  echo "check_virtualization() { return 0; }" >> /tmp/script.sh
  echo "set_pkg_manager() { pkg_manager='apt'; }" >> /tmp/script.sh

  echo "set_update_upgrade_cmds() { update_cmd='echo apt update'; upgrade_cmd='echo apt upgrade -y'; }" >> /tmp/script.sh
  echo "update_packages() { eval \"\$update_cmd\" && msg GREEN 'Repositories updated successfully.' || msg RED 'Failed to update repositories.'; eval \"\$upgrade_cmd\" && msg GREEN 'Packages upgraded successfully.' || msg RED 'Failed to upgrade packages.'; }" >> /tmp/script.sh
  echo "install_microcode() { msg GREEN 'Microcode installed successfully for Intel Xeon.'; }" >> /tmp/script.sh
  echo "identify_gpu() { msg RED 'No GPU detected.'; }" >> /tmp/script.sh

  chmod +x /tmp/script.sh
  export PATH="/tmp:$PATH"
}

teardown() {
  rm -f /tmp/script.sh
}

@test "Display banner does not fail" {
  run /tmp/script.sh -c "display_banner"
  [ "$status" -eq 0 ]
}

@test "Display message in red" {
  run /tmp/script.sh -c "msg 1 'Test message'"
  [ "$output" == "$(tput setaf 1)Test message$(tput sgr0)" ]
}

@test "Check necessary utilities" {
  run /tmp/script.sh -c "for cmd in lscpu awk grep lspci; do command -v \"\$cmd\"; done"
  [ "$status" -eq 0 ]
}

@test "Identify package manager as apt" {
  run /tmp/script.sh -c "set_pkg_manager"
  [ "$pkg_manager" = "apt" ]
}

@test "Update packages function runs without failure" {
  run /tmp/script.sh -c "set_update_upgrade_cmds; update_packages"
  [ "$status" -eq 0 ]
}

@test "Microcode installation logic" {
  run /tmp/script.sh -c "install_microcode"
  [ "$status" -eq 0 ]
}

@test "Identify GPU" {
  run /tmp/script.sh -c "identify_gpu"
  [ "$status" -eq 0 ]
  [ "$output" == "No GPU detected." ] # Ensure this logical condition checks correctly
}

@test "Respond to missing utilities correctly" {
  run /tmp/script.sh -c "command -v lspci; exit 1"
  [ "$status" -ne 0 ]
  [ "$output" == "lspci not installed. Exiting." ]
}

@test "Handle unsupported distribution" {
  run /tmp/script.sh -c "ID=unsupported; set_pkg_manager"
  [ "$status" -ne 0 ]
  [ "$output" == "Unsupported distribution: unsupported." ]
}

@test "Simulate microcode installation" {
  run /tmp/script.sh -c "install_microcode"
  [ "$status" -eq 0 ]
}

@test "Failed update command" {
  run /tmp/script.sh -c "echo 'failed command' && false"
  [ "$status" -ne 0 ]
  [ "$output" == "Failed to update repositories." ]
}

@test "Success message output color verification" {
  run /tmp/script.sh -c "msg 2 'Success Message'"
  [[ "$output" == *"\033[0;32mSuccess Message\033[0m"* ]]
}

@test "Error message output color verification" {
  run /tmp/script.sh -c "msg 1 'Error Message'"
  [[ "$output" == *"\033[0;31mError Message\033[0m"* ]]
}

@test "Identify package manager for multiple distributions" {
  for distro in "ubuntu" "fedora" "arch"; do
    run /tmp/script.sh -c "ID=$distro; set_pkg_manager"
    [ "$pkg_manager" != "" ] 
  done
}
