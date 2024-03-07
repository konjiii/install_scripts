#!/usr/bin/env bash

echo "enter EFI partition:"
read EFI

echo "enter root partition:"
read ROOT

echo "enter swap partition:"
read SWAP

echo "enter username:"
read USER

echo "enter password for $USER:"
read -s PASS
