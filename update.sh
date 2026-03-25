#!/bin/bash
# Daily update script for london-flats GitHub Pages
set -e
REPO_DIR="/Users/glancy/.openclaw/workspace/london-flats"
DATA_DIR="/Users/glancy/.openclaw/workspace/data"

cp "$DATA_DIR/london-flats-app.html" "$REPO_DIR/index.html"
cp "$DATA_DIR/listing-photos.json" "$REPO_DIR/listing-photos.json"

if [ -f "$DATA_DIR/listings-db.json" ]; then
  cp "$DATA_DIR/listings-db.json" "$REPO_DIR/listings-db.json"
fi

cd "$REPO_DIR"
git config user.name "JClaw"
git config user.email "jclaw@candosa.com"
git add -A

if git diff --cached --quiet; then
  echo "No changes to deploy"
else
  git commit -m "Daily update — $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo "Deployed to https://jcg8802.github.io/london-flats/"
fi
