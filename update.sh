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

# ── Vercel deploy (file upload API) ──────────────────────────────────────────
VERCEL_TOKEN="${VERCEL_TOKEN:-$(cat ~/.openclaw/workspace/secrets/vercel.env | grep VERCEL_TOKEN | cut -d= -f2)}"
VERCEL_PROJECT="london-flats"

echo "Deploying to Vercel..."
python3 - <<PYEOF
import requests, hashlib, os, time, json

TOKEN = "$VERCEL_TOKEN"
PROJECT = "$VERCEL_PROJECT"
LOCAL_PATH = "$REPO_DIR"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

skip_dirs  = {'.git', 'node_modules', '.vercel'}
skip_files = {'.DS_Store', '.gitignore'}
files_map  = []

for root, dirs, files in os.walk(LOCAL_PATH):
    dirs[:] = [d for d in dirs if d not in skip_dirs and not d.startswith('.')]
    for fname in files:
        if fname in skip_files or fname.startswith('.'): continue
        fp = os.path.join(root, fname)
        content = open(fp, 'rb').read()
        sha1 = hashlib.sha1(content).hexdigest()
        r = requests.post("https://api.vercel.com/v2/files",
            headers={**{"Content-Type":"application/octet-stream","x-vercel-digest":sha1},
                     "Authorization":f"Bearer {TOKEN}"},
            data=content)
        rel = os.path.relpath(fp, LOCAL_PATH)
        files_map.append({"file": rel, "sha": sha1, "size": len(content)})
        print(f"  [{r.status_code}] {rel}")

payload = {"name": PROJECT, "files": files_map,
           "projectSettings": {"framework": None, "buildCommand": "", "outputDirectory": "."},
           "target": "production"}
dep = requests.post("https://api.vercel.com/v13/deployments", headers=HEADERS, json=payload).json()
dep_id = dep.get('id')
print(f"  Deployment {dep_id} — polling...")
for _ in range(60):
    time.sleep(5)
    d = requests.get(f"https://api.vercel.com/v13/deployments/{dep_id}", headers=HEADERS).json()
    state = d.get('readyState', 'UNKNOWN')
    if state in ('READY', 'ERROR', 'CANCELED'):
        print(f"  {state}: https://{d.get('url','')}")
        break
PYEOF
echo "Vercel deploy complete → https://london-flats.vercel.app"
