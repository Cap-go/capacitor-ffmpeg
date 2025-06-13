#!/bin/bash

# Apply patches to local repositories in rust/ directory
# This script applies local patches to your local repo modifications

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔧 Applying patches to local repositories..."

# Function to apply patches for a specific local repo
apply_repo_patches() {
    local repo_name="$1"
    local patch_dir="$SCRIPT_DIR/$repo_name"
    local repo_path="$RUST_DIR/$repo_name"
    
    if [ ! -d "$patch_dir" ]; then
        echo "ℹ️  No patches found for $repo_name"
        return 0
    fi
    
    if [ ! -d "$repo_path" ]; then
        echo "❌ Local repository $repo_name not found at $repo_path"
        return 1
    fi
    
    echo "📦 Applying patches for $repo_name..."
    echo "📁 Repository path: $repo_path"
    
    # Apply all .patch files in alphabetical order
    for patch_file in "$patch_dir"/*.patch; do
        if [ -f "$patch_file" ]; then
            echo "🩹 Applying $(basename "$patch_file")..."
            cd "$repo_path"
            
            # Check if patch is already applied (to avoid double-application)
            if patch -p1 --dry-run --silent < "$patch_file" 2>/dev/null; then
                patch -p1 < "$patch_file" || {
                    echo "❌ Failed to apply $(basename "$patch_file")"
                    return 1
                }
                echo "✅ Applied $(basename "$patch_file")"
            else
                echo "⚠️  Patch $(basename "$patch_file") appears to be already applied or conflicts exist"
            fi
        fi
    done
    
    echo "✅ Successfully processed patches for $repo_name"
}

# Apply patches for each local repository
apply_repo_patches "ffmpeg-sys"
apply_repo_patches "ffmpeg"

echo "🎉 All local repository patches processed!" 