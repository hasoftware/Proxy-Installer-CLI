#!/bin/bash
# Test script to debug issues

cd "$(dirname "$0")"

echo "Testing script loading..."
bash -x ./auto-proxy-installer.sh 2>&1 | head -n 50

