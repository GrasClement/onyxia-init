#!/bin/bash
# Onyxia VSCode (code-server) init script — settings + extensions + uv
# Idempotent, relancé à chaque démarrage de service.
# Expected parameters : None
set -uo pipefail

SETTINGS_DIR="${HOME}/.local/share/code-server/User"
SETTINGS_FILE="${SETTINGS_DIR}/settings.json"
mkdir -p "$SETTINGS_DIR"
[ -f "$SETTINGS_FILE" ] || echo "{}" > "$SETTINGS_FILE"

jq '. + {
    "workbench.colorTheme": "Default Dark Modern",
    "editor.rulers": [88, 100],
    "editor.fontSize": 14,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "notebook.formatOnCellExecution": true,
    "notebook.defaultFormatter": "charliermarsh.ruff",
    "extensions.ignoreRecommendations": true,
    "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.fixAll.ruff": "always",
            "source.organizeImports.ruff": "always"
        }
    }
}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

for ext in \
    charliermarsh.ruff \
    ms-python.python \
    ms-toolsai.jupyter \
    tamasfe.even-better-toml \
    vscode-icons-team.vscode-icons \
    yzhang.markdown-all-in-one
do
    code-server --install-extension "$ext" || echo "WARN: échec install $ext"
done

pip install --quiet uv