#!/bin/bash

# Generate patches from local repository changes
# This script creates patch files from your current modifications

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔧 Generating patches from local repository changes..."

# Function to generate patch for a specific file
generate_file_patch() {
    local repo_name="$1"
    local file_path="$2"
    local patch_name="$3"
    
    local repo_path="$RUST_DIR/$repo_name"
    local patch_dir="$SCRIPT_DIR/$repo_name"
    local full_file_path="$repo_path/$file_path"
    
    if [ ! -f "$full_file_path" ]; then
        echo "❌ File not found: $full_file_path"
        return 1
    fi
    
    mkdir -p "$patch_dir"
    
    echo "📦 Generating patch for $repo_name/$file_path..."
    
    cd "$repo_path"
    
    # Check if this is a git repository (directory) or submodule (file)
    if [ -d ".git" ] || [ -f ".git" ]; then
        echo "📁 Git repository/submodule detected, using git diff..."
        
        # Generate patch using git diff
        git diff HEAD -- "$file_path" > "$patch_dir/${patch_name}.patch"
        
        if [ -s "$patch_dir/${patch_name}.patch" ]; then
            echo "✅ Generated git patch: $patch_dir/${patch_name}.patch"
        else
            echo "ℹ️  No changes detected in $file_path"
            rm -f "$patch_dir/${patch_name}.patch"
        fi
    else
        echo "⚠️  Not a git repository. You'll need to manually create the patch."
        echo "📋 Manual patch creation needed for: $full_file_path"
        
        # Create a template patch file with current content
        local patch_file="$patch_dir/${patch_name}.patch"
        echo "# Manual patch for $repo_name/$file_path" > "$patch_file"
        echo "# Please create a proper unified diff patch manually" >> "$patch_file"
        echo "# Current file location: $full_file_path" >> "$patch_file"
        
        echo "📝 Template created: $patch_file"
    fi
}

# Generate patch for ffmpeg-sys build.rs
generate_file_patch "ffmpeg-sys" "build.rs" "001-ios-simulator-fixes"
generate_file_patch "ffmpeg" ".gitignore" "001-fix-gitignore"

echo "🎉 Patch generation completed!"
echo ""
echo "📋 To apply patches later, run: ./rust/patches/apply-patches.sh"
echo "📋 Patch files are stored in: rust/patches/" 