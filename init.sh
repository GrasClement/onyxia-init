#!/bin/bash
# Onyxia VSCode (code-server) init script: settings, extensions, uv, git.
# Idempotent, relancé à chaque démarrage de service.
# Expected parameters : None
set -uo pipefail

SETTINGS_DIR="${HOME}/.local/share/code-server/User"
SETTINGS_FILE="${SETTINGS_DIR}/settings.json"
mkdir -p "$SETTINGS_DIR"
[ -f "$SETTINGS_FILE" ] || echo "{}" > "$SETTINGS_FILE"

# User settings 
jq '. + {
    "workbench.colorTheme": "Monokai",
    "workbench.iconTheme": "vscode-icons",
    "workbench.startupEditor": "none",
    "workbench.editorAssociations": { "*.ipynb": "jupyter-notebook" },
    "editor.rulers": [88, 100],
    "editor.fontSize": 14,
    "editor.unicodeHighlight.nonBasicASCII": false,
    "diffEditor.ignoreTrimWhitespace": true,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "terminal.integrated.fontSize": 13,
    "terminal.integrated.defaultProfile.linux": "bash",
    "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
    "python.terminal.activateEnvironment": true,
    "python.terminal.activateEnvInCurrentTerminal": true,
    "python.createEnvironment.trigger": "off",
    "notebook.formatOnCellExecution": true,
    "notebook.defaultFormatter": "charliermarsh.ruff",
    "jupyter.widgetScriptSources": ["jsdelivr.com", "unpkg.com"],
    "basedpyright.analysis.typeCheckingMode": "standard",
    "path-intellisense.autoSlashAfterDirectory": true,
    "git.autofetch": true,
    "git.confirmSync": false,
    "git.enableSmartCommit": true,
    "extensions.ignoreRecommendations": true,
    "telemetry.telemetryLevel": "off",
    "security.workspace.trust.enabled": false,
    "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.fixAll.ruff": "explicit",
            "source.organizeImports.ruff": "explicit"
        }
    }
}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

# Extensions (code-server uses Open VSX, some Microsoft ones may be missing)
installed="$(code-server --list-extensions 2>/dev/null || true)"
for ext in \
    charliermarsh.ruff \
    detachhead.basedpyright \
    christian-kohler.path-intellisense \
    ms-python.python \
    ms-toolsai.jupyter \
    tamasfe.even-better-toml \
    vscode-icons-team.vscode-icons \
    yzhang.markdown-all-in-one
do
    grep -qix "$ext" <<< "$installed" \
        || code-server --install-extension "$ext" \
        || echo "WARN: échec install $ext"
done

# uv (often already in the image; --break-system-packages avoids PEP 668 errors)
command -v uv >/dev/null || pip install --quiet --break-system-packages uv

# Git: feature/ branches workflow
git config --global push.autoSetupRemote true

# Script runs as root: give everything back to the service user
chown -R "${USERNAME:-onyxia}:${GROUPNAME:-users}" "${HOME}"
