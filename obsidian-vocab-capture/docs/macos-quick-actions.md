# macOS Quick Actions for obsidian-vocab-capture

This guide covers four ways to quickly capture English words from any macOS app.

## Prerequisites

```bash
# Install the CLI tool
cd ~/obsidian-vocab-capture
pip install -e .
```

Configure your AI provider (one-time setup):

```bash
obsidian-vocab-capture config init --api-key YOUR_KEY --model gpt-4.1-mini
```

---

## Recommended: PopClip Extension (⭐⭐⭐ Best UX)

PopClip appears as a popup bar whenever you select text. The most seamless option.

### Setup

1. Install [PopClip](https://pilotmoon.com/popclip/) from the Mac App Store
2. Create the extension:

```bash
mkdir -p ~/Library/Application\ Support/PopClip/Extensions/vocab-capture.popclipext
```

3. Create `Config.plist`:

```bash
cat > ~/Library/Application\ Support/PopClip/Extensions/vocab-capture.popclipext/Config.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Extension Name</key>
    <string>Capture Vocab</string>
    <key>Extension Identifier</key>
    <string>com.richard.vocab-capture</string>
    <key>Extension Description</key>
    <string>Add English word to Obsidian vocabulary</string>
    <key>Actions</key>
    <array>
        <dict>
            <key>Title</key>
            <string>📖 Capture Vocab</string>
            <key>Shell Script</key>
            <string>#!/bin/bash
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
~/obsidian-vocab-capture/.venv/bin/obsidian-vocab-capture add "$POPCLIP_TEXT" &
</string>
            <key>After</key>
            <string>show-result</string>
            <key>Result Message</key>
            <string>✅ Added "$POPCLIP_TEXT" to vocabulary</string>
        </dict>
    </array>
    <key>Required Apps</key>
    <array>
        <string>com.apple.Terminal</string>
    </array>
</dict>
</plist>
EOF
```

4. Restart PopClip. Select any English text and click "📖 Capture Vocab".

### Advanced: Two-button PopClip (Capture + Lookup)

Create a second action for quick lookup without saving:

```xml
<dict>
    <key>Title</key>
    <string>🔍 Quick Lookup</string>
    <key>Shell Script</key>
    <string>#!/bin/bash
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
result=$(~/obsidian-vocab-capture/.venv/bin/obsidian-vocab-capture lookup "$POPCLIP_TEXT" 2>&1)
osascript -e "display notification \"$(echo $result | head -3)\" with title \"Vocab Lookup\""
</string>
</dict>
```

---

## Recommended: Raycast Script Command (⭐⭐⭐ Great for keyboard users)

Raycast is a powerful macOS launcher. Use Script Commands for keyboard-driven capture.

### Setup

1. Install [Raycast](https://raycast.com/)
2. Enable Script Commands in Raycast Settings → Extensions → Script Commands
3. Create the script:

```bash
mkdir -p ~/raycast-scripts
cat > ~/raycast-scripts/capture-vocab.sh << 'SCRIPT'
#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Capture Vocab
# @raycast.mode compact
# @raycast.icon 📖
# @raycast.packageName English

# Read clipboard
word=$(pbpaste | tr -d '\n' | xargs)

if [ -z "$word" ]; then
    echo "❌ Clipboard is empty"
    exit 1
fi

# Call the CLI tool
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
output=$(~/obsidian-vocab-capture/.venv/bin/obsidian-vocab-capture add "$word" 2>&1)

echo "$output"
SCRIPT

chmod +x ~/raycast-scripts/capture-vocab.sh
```

4. In Raycast: Settings → Extensions → Script Commands → Add Directory → select `~/raycast-scripts`
5. Usage: `Cmd+Space` → type "Capture Vocab" → Enter

### Option: Raycast Shortcut

You can bind "Capture Vocab" to a global hotkey in Raycast Settings → Extensions → Script Commands → Capture Vocab → Record Hotkey.

---

## Option: Automator Quick Action (⭐ Good for native-only users)

Creates a macOS Service that appears in the right-click menu.

### Setup

1. Open Automator → New Document → Quick Action
2. Configure:
   - Workflow receives: **text**
   - In: **any application**
   - Check: **Output replaces selected text** (uncheck this)

3. Add **Run Shell Script** action with:

```bash
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
~/obsidian-vocab-capture/.venv/bin/obsidian-vocab-capture add "$1" &
```

   - Set **Pass input**: **as arguments**

4. Save as "Capture Vocab"

5. Bind a keyboard shortcut:
   - System Preferences → Keyboard → Shortcuts → Services
   - Find "Capture Vocab" → Click "none" → Press your shortcut (e.g., `Cmd+Shift+V`)

### Usage

Select text → Right-click → Services → Capture Vocab
Or: Select text → Press your keyboard shortcut

---

## Option: macOS Shortcuts (⭐ Works everywhere, simpler setup)

### Setup

1. Open **Shortcuts** app
2. Create new shortcut:
   - Name: "Capture Vocab"
   - Add action: **Get Clipboard**
   - Add action: **Run Shell Script**
     - Shell: `/bin/zsh`
     - Input: `Shortcut Input`
     - Script:

```bash
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
word=$(echo "$1" | tr -d '\n' | xargs)
~/obsidian-vocab-capture/.venv/bin/obsidian-vocab-capture add "$word" 2>&1
```

   - Add action: **Show Notification** with result

3. Optional: Bind to keyboard shortcut in Shortcuts settings

### Improved: Receive Selected Text

For better UX, change "Get Clipboard" to "Receive Shortcut Input" → set to receive text. This way you can:
- Copy text, then run the shortcut
- Or select text in supported apps

---

## Comparison

| Method | Setup Difficulty | Speed | Keyboard-friendliness | Cost |
|--------|-----------------|-------|-----------------------|------|
| PopClip | Easy | ⭐⭐⭐ | ⭐⭐ | ~$15 |
| Raycast | Medium | ⭐⭐⭐ | ⭐⭐⭐ | Free |
| Automator | Medium | ⭐⭐ | ⭐⭐ | Free (built-in) |
| Shortcuts | Easy | ⭐⭐ | ⭐ | Free (built-in) |

**Recommendation**: PopClip for visual/mouse-oriented users, Raycast for keyboard-heavy users.
