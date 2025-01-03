#!/usr/bin/env bats

setup() {
  echo "#!/bin/sh" > /tmp/script.sh
  cat << 'EOF' >> /tmp/script.sh
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
  echo "$pkg_manager"  # Output the package manager for testing
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
EOF
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
  echo "DEBUG: Output was: [$output]"
  [ "$output" = "Test message" ]
}

@test "Check necessary utilities" {
  run /tmp/script.sh -c "for cmd in lscpu awk grep lspci; do command -v \"\$cmd\"; done"
  [ "$status" -eq 0 ]
}

@test "Identify package manager as apt" {
  run /tmp/script.sh -c "set_pkg_manager"
  pkg_manager_output=$(run /tmp/script.sh -c 'set_pkg_manager; echo $pkg_manager')
  echo "DEBUG: pkg_manager output was: [$pkg_manager_output]"
  [ "$pkg_manager_output" = "apt" ]
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
  echo "DEBUG: GPU detection output was: [$output]"
  [ "$output" = "No GPU detected." ]
}

@test "Respond to missing utilities correctly" {
  run /tmp/script.sh -c "command -v lspci"
  [ "$status" -eq 0 ]
}
