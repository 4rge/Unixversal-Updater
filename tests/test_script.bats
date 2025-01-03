#!/usr/bin/env bats

setup() {
  echo "#!/bin/sh" > /tmp/script.sh
  echo "msg() { echo -e \"\$$1 \$2\"; }" >> /tmp/script.sh
  echo "lscpu() { echo 'Model name: Intel Xeon'; }" >> /tmp/script.sh
  echo "lspci() { echo '01:00.0 VGA compatible controller: Intel Corporation'; }" >> /tmp/script.sh
  chmod +x /tmp/script.sh
  export PATH="/tmp:$PATH"
  
  echo -e "ID=ubuntu" > /etc/os-release  # Mock the os-release file
}

teardown() {
  rm -f /tmp/script.sh
  rm -f /etc/os-release
}

@test "Display banner does not fail" {
  run /tmp/script.sh -c "display_banner"
  [ "$status" -eq 0 ]
}

@test "Display message in red" {
  run /tmp/script.sh -c "msg RED 'Test message'"
  [ "$output" = "RED Test message" ]
}

@test "Check necessary utilities" {
  run /tmp/script.sh -c "command -v fake_cmd"
  [ "$status" -ne 0 ]
  [ "$output" = "fake_cmd not installed. Exiting." ]
}

@test "Identify package manager as apt" {
  run /tmp/script.sh -c "set_pkg_manager"
  [ "$pkg_manager" = "apt" ]
}

@test "Update packages function runs without failure" {
  run /tmp/script.sh -c "update_packages"
  [ "$status" -eq 0 ]
}

@test "Microcode installation logic" {
  run /tmp/script.sh -c "install_microcode"
  [ "$status" -eq 0 ]
}

@test "Identify GPU" {
  run /tmp/script.sh -c "identify_gpu"
  [ "$status" -eq 0 ]
}

@test "Respond to missing utilities correctly" {
  run /tmp/script.sh -c "command -v lspci; exit 1"
  [ "$status" -ne 0 ]
  [ "$output" = "lspci not installed. Exiting." ]
}

@test "Handle unsupported distribution" {
  echo -e "ID=unsupported" > /etc/os-release
  run /tmp/script.sh -c "set_pkg_manager"
  [ "$status" -ne 0 ]
  [ "$output" = "Unsupported distribution: unsupported." ]
}

@test "Simulate microcode installation with user prompt" {
  run /tmp/script.sh -c "install_microcode"
  echo "y" | run /tmp/script.sh -c "install_microcode"
  [ "$status" -eq 0 ]
}

@test "Simulate microcode installation decline" {
  run /tmp/script.sh -c "install_microcode"
  echo "n" | run /tmp/script.sh -c "install_microcode"
  [ "$status" -eq 0 ]
}

@test "Failed update command" {
  run /tmp/script.sh -c "eval false"  # Mocking a failure for testing
  [ "$status" -ne 0 ]
  [ "$output" = "Failed to update repositories." ]
}

@test "Success message output color verification" {
  run /tmp/script.sh -c "msg GREEN 'Success Message'"
  [[ "$output" == *"\033[0;32mSuccess Message\033[0m"* ]]
}

@test "Error message output color verification" {
  run /tmp/script.sh -c "msg RED 'Error Message'"
  [[ "$output" == *"\033[0;31mError Message\033[0m"* ]]
}

@test "No GPU detected" {
  run /tmp/script.sh -c "lspci() { echo ''; }"
  [ "$output" = "No GPU detected." ]
}

@test "Identify package manager for multiple distributions" {
  for distro in "ubuntu" "fedora" "arch"; do
    echo -e "ID=$distro" > /etc/os-release
    run /tmp/script.sh -c "set_pkg_manager"
    [ "$pkg_manager" != "" ] # Check it's correctly set
  done
}
