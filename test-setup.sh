#!/bin/bash

echo "=== Testing Redmine + OpenSearch Setup ==="

echo "1. Testing OpenSearch..."
if curl -s http://localhost:9200 > /dev/null; then
    echo "✅ OpenSearch is running at http://localhost:9200"
else
    echo "❌ OpenSearch is not accessible"
    exit 1
fi

echo "2. Testing Redmine..."
if curl -s -I http://localhost:3000 | grep -q "200 OK"; then
    echo "✅ Redmine is running at http://localhost:3000"
else
    echo "❌ Redmine is not accessible"
    exit 1
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Open http://localhost:3000 in your browser"
echo "2. Log in with admin/admin"
echo "3. Create some test issues and projects"
echo "4. Get your API key from 'My account'"
echo "5. Run the ETL script to index data:"
echo "   # Add your API key to .env file:"
echo "   echo 'REDMINE_API_KEY=your_api_key_here' >> .env"
echo "   docker-compose --profile etl up etl"
echo "6. Test semantic search at http://localhost:3000/rass"
echo ""
echo "=== Quick Test Commands ==="
echo "- Check OpenSearch: curl http://localhost:9200"
echo "- Check Redmine: curl http://localhost:3000"
echo "- View logs: docker-compose logs" 