#!/bin/bash
set -e


# Check if the default Rust comes from rustup, based on the official
# recommended method of installation:
# https://www.rust-lang.org/learn/get-started
declare is_rustup_default=$(rustup show | awk '/\(default\)/')


# If Rust comes from rustup, update Rust
if [[ $is_rustup_default ]]; then

    rustup update

else
    # Run script to install Rust and it's dependencies, based on the official
    # recommended method of installation
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

fi
