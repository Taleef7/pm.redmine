#!/bin/bash

echo "=== Running ETL Process ==="

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "Please create .env file with your Redmine API key:"
    echo "echo 'REDMINE_API_KEY=your_api_key_here' > .env"
    exit 1
fi

# Check if REDMINE_API_KEY is set in .env
if ! grep -q "REDMINE_API_KEY=" .env; then
    echo "❌ REDMINE_API_KEY not found in .env file!"
    echo "Please add your API key to .env file:"
    echo "echo 'REDMINE_API_KEY=your_api_key_here' >> .env"
    exit 1
fi

echo "✅ Using API key from .env file"
echo "🚀 Starting ETL process..."

# Run the ETL
docker-compose --profile etl up etl

echo ""
echo "✅ ETL process completed!"
echo "🌐 Test OpenSearch at: http://localhost:9200" 