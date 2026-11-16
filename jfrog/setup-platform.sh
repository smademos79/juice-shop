#!/usr/bin/env bash
# Creates the repositories, Xray policy and watch used by the secure pipeline.
# Prerequisite: `jf config add` (or `jf c add --interactive`) with an ADMIN access token.
# Curation policies and the GitHub OIDC integration are configured in the UI (see README).
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Repositories"
for f in repos/*.json; do
  key=$(sed -n 's/.*"key": *"\([^"]*\)".*/\1/p' "$f" | head -1)
  if jf rt curl -s -o /dev/null -w '%{http_code}' "/api/repositories/${key}" | grep -q 200; then
    echo "   ${key} exists, updating"; jf rt repo-update "$f"
  else
    echo "   creating ${key}"; jf rt repo-create "$f"
  fi
done

echo "==> Xray: index builds named juice-shop"
jf xr curl -s -XPOST /api/v1/binMgr/builds -H 'Content-Type: application/json' \
  -d '{"names":["juice-shop"]}' || echo "   (configure in UI: Administration > Xray Settings > Indexed Resources > Builds)"

echo "==> Xray: policy + watch"
jf xr curl -s -XPOST /api/v2/policies -H 'Content-Type: application/json' -d @xray/policy-security-gate.json; echo
jf xr curl -s -XPOST /api/v2/watches  -H 'Content-Type: application/json' -d @xray/watch-juice-shop.json; echo
echo "Done. Next: enable Curation on juice-npm-remote / juice-dockerhub-remote / juice-gcr-remote in the UI."
