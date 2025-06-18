#!/bin/bash

# Simple test script to verify monorepo structure
set -e

echo "🔍 Testing Redmine Monorepo Structure..."

# Test 1: Check if submodules are properly initialized
echo "📁 Testing submodules..."
if [ ! -d "redmine" ]; then
    echo "❌ Redmine submodule not found"
    exit 1
fi

if [ ! -d "plugins/additionals" ]; then
    echo "❌ Additionals plugin submodule not found"
    exit 1
fi

if [ ! -d "plugins/clipboard_image_paste" ]; then
    echo "❌ Clipboard image paste plugin submodule not found"
    exit 1
fi

echo "✅ All submodules present"

# Test 2: Check Redmine version
echo "🏷️  Testing Redmine version..."
cd redmine
if grep -q "MAJOR = 6" lib/redmine/version.rb && grep -q "MINOR = 0" lib/redmine/version.rb; then
    echo "✅ Redmine 6.0.x detected"
else
    echo "❌ Unexpected Redmine version"
    exit 1
fi
cd ..

# Test 3: Check plugin structure
echo "🔌 Testing plugin structure..."
if [ ! -f "plugins/additionals/init.rb" ]; then
    echo "❌ Additionals plugin init.rb not found"
    exit 1
fi

if [ ! -f "plugins/clipboard_image_paste/init.rb" ]; then
    echo "❌ Clipboard image paste plugin init.rb not found"
    exit 1
fi

echo "✅ All plugins have init.rb files"

# Test 4: Check Docker infrastructure
echo "🐳 Testing Docker infrastructure..."
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found"
    exit 1
fi

if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi

if [ ! -f "init-plugins.sh" ]; then
    echo "❌ init-plugins.sh not found"
    exit 1
fi

echo "✅ All Docker files present"

# Test 5: Check configuration files
echo "⚙️  Testing configuration..."
if [ ! -f "config/database.yml" ]; then
    echo "❌ Database configuration not found"
    exit 1
fi

if [ ! -f ".env.example" ]; then
    echo "❌ Environment template not found"
    exit 1
fi

echo "✅ Configuration files present"

# Test 6: Check workflow
echo "🔄 Testing CI/CD workflow..."
if [ ! -f ".github/workflows/build-test.yml" ]; then
    echo "❌ GitHub workflow not found"
    exit 1
fi

echo "✅ GitHub workflow present"

echo ""
echo "🎉 All tests passed! Monorepo structure is correct."
echo ""
echo "📊 Summary:"
echo "   - Redmine 6.0.x (stable)"
echo "   - 2 plugins included"
echo "   - Docker infrastructure ready"
echo "   - CI/CD workflow configured"
echo ""
echo "🚀 To start: docker-compose up"