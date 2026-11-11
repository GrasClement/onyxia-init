#!/bin/bash
# Onyxia VSCode (code-server) init script: settings, extensions, uv, git,
# + outils de travail (gh, Claude Code) et réglages personnels de Claude Code.
# Idempotent, relancé à chaque démarrage de service. Tourne en root, HOME=/home/onyxia.
# Aucun secret ici : Onyxia injecte GIT_PERSONAL_ACCESS_TOKEN (et AWS_* pour MinIO) dans l'environnement.
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
    yzhang.markdown-all-in-one \
    bierner.markdown-mermaid \
    anthropic.claude-code
do
    grep -qix "$ext" <<< "$installed" \
        || code-server --install-extension "$ext" \
        || echo "WARN: échec install $ext"
done

# uv (often already in the image; --break-system-packages avoids PEP 668 errors)
command -v uv >/dev/null || pip install --quiet --break-system-packages uv

# Git: feature/ branches workflow
git config --global push.autoSetupRemote true

# ---------------------------------------------------------------------------
# Outils de travail
# ---------------------------------------------------------------------------
# gh (paquet Ubuntu) ; authentifié sans login par le jeton Git d'Onyxia (Mon compte > Git)
command -v gh >/dev/null || { apt-get update -qq && apt-get install -y -qq gh; } || echo "WARN: échec install gh"
BASHRC="${HOME}/.bashrc"
ajouter_bashrc() {  # $1 = motif déjà présent ?, $2 = ligne à ajouter (idempotent)
    grep -qF -- "$1" "$BASHRC" 2>/dev/null || echo "$2" >> "$BASHRC"
}
ajouter_bashrc 'GH_TOKEN=' 'export GH_TOKEN="${GIT_PERSONAL_ACCESS_TOKEN:-}"   # gh sans login (init Onyxia)'
ajouter_bashrc 'gh completion' 'eval "$(gh completion -s bash)"'

# Claude Code, installeur natif officiel : binaire dans ~/.local/bin, que les terminaux de
# code-server (shells non-login, qui ne lisent pas ~/.profile) n'ont pas dans le PATH par défaut
ajouter_bashrc '.local/bin:$PATH' 'export PATH="$HOME/.local/bin:$PATH"'
export PATH="${HOME}/.local/bin:${PATH}"
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash || echo "WARN: échec install claude"

# Environnement Python du dépôt (si Onyxia l'a déjà cloné dans ~/work)
for depot in "${HOME}"/work/*/; do
    [ -f "${depot}pyproject.toml" ] && (cd "$depot" && uv sync --quiet) || true
done

# Réglages personnels de Claude Code (seule chose utile à recréer : ~/.claude est vierge à chaque pod).
# Fusion jq : ne remplace que ces clés. Connexion : `claude` puis /login (jeton jamais stocké).
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
mkdir -p "${HOME}/.claude"
[ -f "$CLAUDE_SETTINGS" ] || echo "{}" > "$CLAUDE_SETTINGS"
jq '. + {
    "model": "sonnet",
    "theme": "dark"
}' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"

# Script runs as root: give everything back to the service user
chown -R "${USERNAME:-onyxia}:${GROUPNAME:-users}" "${HOME}"
