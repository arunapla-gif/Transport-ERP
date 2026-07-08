#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Local Print Agent..."
echo "Installing required packages..."
npm install
echo "Starting server..."
node server.js
