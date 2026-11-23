#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Copying custom shrinkwrap configs..."
cp -r ./config/* ../shrinkwrap/config/

echo "[*] Applying DICE patches to TF-A, RMM, Linux, and Buildroot External CCA..."

git -C "$SCRIPT_DIR/../workspace/source/cca-3world/tfa" apply "$SCRIPT_DIR"/patches/tfa/*
git -C "$SCRIPT_DIR/../workspace/source/cca-3world/rmm" apply "$SCRIPT_DIR"/patches/rmm/*
git -C "$SCRIPT_DIR/../workspace/source/cca-3world/linux" apply "$SCRIPT_DIR"/patches/linux/*
git -C "$SCRIPT_DIR/../workspace/source/cca-3world/buildroot-external-cca" apply "$SCRIPT_DIR"/patches/buildroot-external-cca/*

echo "[+] Build complete. Patches applied successfully."
