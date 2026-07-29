#!/bin/bash
# Looper installer
# Creates symlinks for the looper CLI and both Claude/Codex skills.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing Looper...${NC}"

# Create directories if needed
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.claude/skills"
mkdir -p "$HOME/.codex/skills"

# Symlink the CLI (primary command)
if [ -L "$HOME/bin/looper" ] || [ -f "$HOME/bin/looper" ]; then
    rm -f "$HOME/bin/looper"
fi
ln -s "$SCRIPT_DIR/bin/looper" "$HOME/bin/looper"
chmod +x "$SCRIPT_DIR/bin/looper"
echo "Linked: $HOME/bin/looper -> $SCRIPT_DIR/bin/looper"

link_skill() {
    local skills_root="$1"
    local skill_name="$2"
    local target_path="$skills_root/$skill_name"

    if [ -L "$target_path" ]; then
        rm "$target_path"
    elif [ -d "$target_path" ]; then
        echo -e "${YELLOW}Warning: $target_path exists and is not a symlink. Skipping.${NC}"
        return 0
    elif [ -f "$target_path" ]; then
        echo -e "${YELLOW}Warning: $target_path exists and is a file. Skipping.${NC}"
        return 0
    fi

    ln -s "$SCRIPT_DIR/skills/$skill_name" "$target_path"
    echo "Linked: $target_path -> $SCRIPT_DIR/skills/$skill_name"
}

# Symlink skills for both Claude and Codex.
for skills_root in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
    for skill in looper prd; do
        link_skill "$skills_root" "$skill"
    done
done

echo ""
echo -e "${GREEN}Looper installed!${NC}"
echo ""

# Check if ~/bin is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "$HOME/bin"; then
    echo -e "${YELLOW}Note: ~/bin is not in your PATH.${NC}"
    echo "Add this to your ~/.zshrc or ~/.bashrc:"
    echo ""
    echo '  export PATH="$HOME/bin:$PATH"'
    echo ""
    echo "Then run: source ~/.zshrc"
fi

echo "Usage:"
echo "  1. Run: looper prepare --prd PATH (or --spec PATH)"
echo "  2. Inspect source.md, stories.json, and decomposition approval artifacts"
echo "  3. Run: looper [max_iterations] (or use looper start to prepare and run)"
