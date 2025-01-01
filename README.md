# *nixversal Updater Script

This script is designed to automate the process of updating and upgrading system packages across various Linux distributions. It includes functionalities to check for necessary utilities, identify the package manager, and manage CPU microcode installations.

## Features

- **Cross-Distro Support**: Detects the type of Linux distribution and uses the appropriate package manager (`apt`, `dnf`, `pacman`, etc.).
- **Microcode Management**: Checks and installs/updates CPU microcode based on the detected CPU model (Intel or AMD).
- **GPU Identification**: Displays the detected GPU model using `lspci`.
- **Color-Coded Messages**: Provides feedback on script execution status using different colors for success, error, warning, and information messages.

## Requirements

Before running the script, ensure the following utilities are installed:

- `lscpu`
- `awk`
- `grep`
- `lspci`

These utilities are typically available on most Linux distributions by default.

## Overview

The script will perform the following actions:

1. Display a banner.
2. Check for virtualization, and if detected, will modify its behavior accordingly.
3. Identify and set the package manager based on the operating system.
4. Update the package repositories and upgrade installed packages.
5. Check for the appropriate CPU microcode package, prompting for installation or update if necessary.
6. Identify and display the detected GPU model.

## Customization

You may customize the behavior of the script by modifying the following sections:

- **Color Definitions**: Adjust the color schemes by changing the ANSI escape codes defined at the beginning of the script.
- **Packages**: Add or change the definitions for the microcode packages if your CPU model is not covered.

## Troubleshooting

If you encounter any issues:

- Ensure you are running the script with sufficient permissions.
- Check that all required utilities are installed.
- Review the output messages for any specific errors or warnings.

## License

This script is licensed under the MIT License. Feel free to modify and distribute it as needed.

## Author Information

Created by 4rge

## Acknowledgments

Thanks to the open-source community for the various utilities and tools utilized in this script.
