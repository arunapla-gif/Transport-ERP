#!/bin/bash
cd "/Users/arun_ap/Desktop/crackers erp"

# Remove everything from the git index without deleting the files locally
git rm -r --cached .

# Re-add everything (this time it will respect the updated .gitignore)
git add .

# Amend the previous commit to remove the massive files
git commit --amend -m "Initial commit for Crackers ERP cloud deployment (optimized)"

# Push forcefully (since we amended the commit)
git push -u origin main -f
