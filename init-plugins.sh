#!/bin/bash

# Script to symlink plugins from host to Redmine plugins directory

set -e

echo "Initializing Redmine plugins..."

# Remove any existing plugins directory content
rm -rf /usr/src/redmine/plugins/*

# Create symlinks for each plugin in the plugins directory
if [ -d "/usr/src/redmine/plugins-source" ]; then
    for plugin_dir in /usr/src/redmine/plugins-source/*/; do
        if [ -d "$plugin_dir" ]; then
            plugin_name=$(basename "$plugin_dir")
            echo "Linking plugin: $plugin_name"
            ln -sf "$plugin_dir" "/usr/src/redmine/plugins/$plugin_name"
        fi
    done
else
    echo "No plugins-source directory found, skipping plugin initialization"
fi

echo "Plugin initialization completed"