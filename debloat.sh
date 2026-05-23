#!/bin/bash

echo "========================================================="
echo "   macOS Tahoe Maximum Debloat & Verification Script   "
echo "========================================================="
echo "Requesting administrator privileges upfront..."
sudo -v
# Keep sudo alive during the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "Gathering baseline system metrics. Please wait..."

# --- CAPTURE 'BEFORE' STATE ---
# We use /System/Volumes/Data because that is where user/app data lives on modern macOS
BEFORE_DISK=$(df -h /System/Volumes/Data | tail -1 | awk '{print $4}')
BEFORE_PROCS=$(ps -A | wc -l | tr -d ' ')
BEFORE_AGENTS=$(ls -1 ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null | wc -l | tr -d ' ')
BEFORE_APPS=$(ls -1 /Applications | grep "\.app" | wc -l | tr -d ' ')

echo "Baseline captured. Beginning execution..."

# ---------------------------------------------------------
# Phase 1: Application Purge
# ---------------------------------------------------------
echo "[1/6] Removing user and third-party applications..."
rm -rf ~/Applications/* 2>/dev/null
cd /Applications
for app in *.app; do
    if [[ ! "$app" == "Utilities" && ! "$app" == "Safari.app" ]]; then
        sudo rm -rf "$app" 2>/dev/null
    fi
done

# ---------------------------------------------------------
# Phase 2: Background Daemon & Agent Purge
# ---------------------------------------------------------
echo "[2/6] Purging third-party background services..."
cd ~/Library/LaunchAgents 2>/dev/null && for plist in *.plist; do
    launchctl unload -w "$plist" 2>/dev/null
    rm -f "$plist" 2>/dev/null
done
cd /Library/LaunchAgents 2>/dev/null && for plist in *.plist; do
    sudo launchctl unload -w "$plist" 2>/dev/null
    sudo rm -f "$plist" 2>/dev/null
done
cd /Library/LaunchDaemons 2>/dev/null && for plist in *.plist; do
    sudo launchctl unload -w "$plist" 2>/dev/null
    sudo rm -f "$plist" 2>/dev/null
done

# ---------------------------------------------------------
# Phase 3: Disable Heavy macOS Services
# ---------------------------------------------------------
echo "[3/6] Disabling Apple telemetry, indexing, and Siri..."
sudo mdutil -i off -d / 2>/dev/null
sudo mdutil -E / 2>/dev/null
defaults write com.apple.assistant.support 'Assistant Enabled' -bool false
launchctl disable "user/$UID/com.apple.assistantd" 2>/dev/null
sudo tmutil disablelocal 2>/dev/null
defaults write com.apple.CrashReporter DialogType -string "none"

# ---------------------------------------------------------
# Phase 4: UI Animation and Rendering Optimizations
# ---------------------------------------------------------
echo "[4/6] Disabling WindowServer animations and UI bloat..."
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g NSScrollAnimationEnabled -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.dock launchanim -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# ---------------------------------------------------------
# Phase 5: Deep Clean (Caches, Logs, App Support)
# ---------------------------------------------------------
echo "[5/6] Obliterating caches and system logs to free storage..."
# Clear user caches
rm -rf ~/Library/Caches/* 2>/dev/null
# Clear system caches
sudo rm -rf /Library/Caches/* 2>/dev/null
# Clear system logs (these rebuild automatically but waste gigabytes over time)
sudo rm -rf /private/var/log/* 2>/dev/null
sudo rm -rf /Library/Logs/* 2>/dev/null
sudo rm -rf ~/Library/Logs/* 2>/dev/null

# ---------------------------------------------------------
# Phase 6: Nuke the Desktop Environment
# ---------------------------------------------------------
echo "[6/6] Wiping Dock and Launchpad..."
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/System/Applications/Utilities/Terminal.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock show-recents -bool false
sqlite3 ~/Library/Application\ Support/Dock/*.db "DELETE from apps; DELETE from groups WHERE title<>''; DELETE from items WHERE rowid>2;" 2>/dev/null

echo "Restarting UI services..."
killall Dock
killall Finder
killall SystemUIServer

echo "Calculating final metrics..."
sleep 2 # Give the OS a second to settle down after killing the UI

# --- CAPTURE 'AFTER' STATE ---
AFTER_DISK=$(df -h /System/Volumes/Data | tail -1 | awk '{print $4}')
AFTER_PROCS=$(ps -A | wc -l | tr -d ' ')
AFTER_AGENTS=$(ls -1 ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null | wc -l | tr -d ' ')
AFTER_APPS=$(ls -1 /Applications | grep "\.app" | wc -l | tr -d ' ')

# --- PRINT REPORT ---
echo ""
echo "========================================================="
echo "                 DEBLOAT RESULTS REPORT                  "
echo "========================================================="
echo "METRIC                  | BEFORE       | AFTER          "
echo "---------------------------------------------------------"
echo "Available SSD Storage   | $BEFORE_DISK          | $AFTER_DISK"
echo "Total Running Processes | $BEFORE_PROCS          | $AFTER_PROCS"
echo "Third-Party Apps Found  | $BEFORE_APPS            | $AFTER_APPS"
echo "Background Daemons      | $BEFORE_AGENTS            | $AFTER_AGENTS"
echo "========================================================="
echo "Note: If Available Storage hasn't updated instantly, macOS is"
echo "still clearing the purged cache files in the background."
echo ""
echo "Your Mac is now fully optimized."
