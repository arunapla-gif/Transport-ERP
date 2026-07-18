#!/bin/bash
cd "/Users/arun_ap/Desktop/crackers erp"

# Initialize Git
git init

# Set default branch to main
git branch -m main

# Add files (respecting .gitignore)
git add .

# Commit
git commit -m "Initial commit for Crackers ERP cloud deployment"

# Add remote
git remote add origin https://github.com/arunapla-gif/crackers_erp.git

# Push to remote
git push -u origin main
