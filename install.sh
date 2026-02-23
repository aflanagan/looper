#!/bin/bash
# Looper installer
# Creates symlinks for the looper CLI and Claude Code skills.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing Looper...${NC}"

# Create directories if needed
mkdir -p ~/bin
mkdir -p ~/.claude/skills

# Symlink the CLI (primary command)
if [ -L ~/bin/looper ] || [ -f ~/bin/looper ]; then
    rm -f ~/bin/looper
fi
ln -s "$SCRIPT_DIR/bin/looper" ~/bin/looper
chmod +x "$SCRIPT_DIR/bin/looper"
echo "Linked: ~/bin/looper -> $SCRIPT_DIR/bin/looper"

# Compatibility alias for existing workflows
if [ -L ~/bin/ralph ] || [ -f ~/bin/ralph ]; then
    rm -f ~/bin/ralph
fi
ln -s "$SCRIPT_DIR/bin/looper" ~/bin/ralph
echo "Linked: ~/bin/ralph -> $SCRIPT_DIR/bin/looper (compatibility alias)"

# Symlink skills
for skill in looper prd; do
    if [ -L ~/.claude/skills/$skill ]; then
        rm ~/.claude/skills/$skill
    elif [ -d ~/.claude/skills/$skill ]; then
        echo -e "${YELLOW}Warning: ~/.claude/skills/$skill exists and is not a symlink. Skipping.${NC}"
        continue
    fi
    ln -s "$SCRIPT_DIR/skills/$skill" ~/.claude/skills/$skill
    echo "Linked: ~/.claude/skills/$skill -> $SCRIPT_DIR/skills/$skill"
done

# Legacy skill alias (/ralph -> /looper)
if [ -d ~/.claude/skills/ralph ] && [ ! -L ~/.claude/skills/ralph ]; then
    echo -e "${YELLOW}Warning: ~/.claude/skills/ralph exists and is not a symlink. Skipping legacy alias.${NC}"
else
    rm -f ~/.claude/skills/ralph
    ln -s "$SCRIPT_DIR/skills/looper" ~/.claude/skills/ralph
    echo "Linked: ~/.claude/skills/ralph -> $SCRIPT_DIR/skills/looper (compatibility alias)"
fi

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
echo "  1. In any project, create .ai/looper/prd.json (use /looper skill)"
echo "  2. Optionally create .ai/looper/config.md for project-specific config"
echo "  3. Run: looper [max_iterations]"
