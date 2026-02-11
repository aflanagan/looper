#!/bin/bash
# Ralph installer
# Creates symlinks for the ralph CLI and Claude Code skills

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing Ralph...${NC}"

# Create directories if needed
mkdir -p ~/bin
mkdir -p ~/.claude/skills

# Symlink the CLI
if [ -L ~/bin/ralph ]; then
    rm ~/bin/ralph
fi
ln -s "$SCRIPT_DIR/bin/ralph" ~/bin/ralph
chmod +x "$SCRIPT_DIR/bin/ralph"
echo "Linked: ~/bin/ralph -> $SCRIPT_DIR/bin/ralph"

# Symlink skills
for skill in ralph prd; do
    if [ -L ~/.claude/skills/$skill ]; then
        rm ~/.claude/skills/$skill
    elif [ -d ~/.claude/skills/$skill ]; then
        echo -e "${YELLOW}Warning: ~/.claude/skills/$skill exists and is not a symlink. Skipping.${NC}"
        continue
    fi
    ln -s "$SCRIPT_DIR/skills/$skill" ~/.claude/skills/$skill
    echo "Linked: ~/.claude/skills/$skill -> $SCRIPT_DIR/skills/$skill"
done

echo ""
echo -e "${GREEN}Ralph installed!${NC}"
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
echo "  1. In any project, create .claude/prd.json (use /ralph skill)"
echo "  2. Optionally create .claude/ralph-config.md for project-specific config"
echo "  3. Run: ralph [max_iterations]"
