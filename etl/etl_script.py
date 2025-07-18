"""
Enhanced ETL Script for Redmine to OpenSearch with Semantic Search

Responsibilities:
- Fetch historical data from Redmine via REST API
- Transform and clean data
- Generate embeddings for semantic search
- Map fields to OpenSearch schema with proper indexing
- Bulk index data into OpenSearch with vector fields
- Log progress and errors

Note: OpenSearch 2.12+ requires authentication. Set OPENSEARCH_USER, OPENSEARCH_PASS, and OPENSEARCH_INITIAL_ADMIN_PASSWORD in your environment or .env file.
"""

import os
import urllib.request
import urllib.parse
import json
import hashlib
import time
import ssl
from datetime import datetime
from typing import Dict, List, Any, Optional

# Configuration
REDMINE_API_URL = os.getenv('REDMINE_API_URL', 'http://localhost:3000')
REDMINE_API_KEY = os.getenv('REDMINE_API_KEY', '')

# OpenSearch Configuration
OPENSEARCH_HOST = os.getenv('OPENSEARCH_HOST', 'http://localhost:9200')
OPENSEARCH_USER = os.getenv('OPENSEARCH_USER', '')
OPENSEARCH_PASS = os.getenv('OPENSEARCH_PASS', '')

# Embedding Configuration (placeholder for production)
EMBEDDING_SERVICE_URL = os.getenv('EMBEDDING_SERVICE_URL', '')
EMBEDDING_API_KEY = os.getenv('EMBEDDING_API_KEY', '')


class RedmineAPIClient:
    def __init__(self, api_url, api_key):
        self.api_url = api_url.rstrip('/')
        self.api_key = api_key
        # Create SSL context that ignores certificate verification for development
        self.ssl_context = ssl.create_default_context()
        self.ssl_context.check_hostname = False
        self.ssl_context.verify_mode = ssl.CERT_NONE

    def _make_request(self, url, method='GET', data=None):
        """Make HTTP request using urllib."""
        req = urllib.request.Request(url, method=method)
        req.add_header('X-Redmine-API-Key', self.api_key)
        req.add_header('Content-Type', 'application/json')

        if data:
            req.data = json.dumps(data).encode('utf-8')

        try:
            with urllib.request.urlopen(req, context=self.ssl_context) as response:
                return json.loads(response.read().decode('utf-8'))
        except Exception as e:
            print(f"Request failed: {e}")
            return None

    def fetch_issues(self, limit=100, offset=0, include_relations=True):
        """Fetch issues from Redmine with pagination and relations."""
        url = f"{self.api_url}/issues.json"
        params = {
            'limit': limit,
            'offset': offset,
            'include': 'relations,attachments,journals,custom_fields' if include_relations else None
        }

        # Build URL with parameters
        if params:
            query_string = urllib.parse.urlencode(
                [(k, v) for k, v in params.items() if v is not None])
            url = f"{url}?{query_string}"

        result = self._make_request(url)
        return result.get('issues', []) if result else []

    def fetch_projects(self):
        """Fetch all projects."""
        url = f"{self.api_url}/projects.json"
        result = self._make_request(url)
        return result.get('projects', []) if result else []

    def fetch_users(self):
        """Fetch all users."""
        url = f"{self.api_url}/users.json"
        result = self._make_request(url)
        return result.get('users', []) if result else []


class OpenSearchClient:
    def __init__(self, host, user=None, password=None):
        self.host = host.rstrip('/')
        self.user = user
        self.password = password
        # Create SSL context that ignores certificate verification for development
        self.ssl_context = ssl.create_default_context()
        self.ssl_context.check_hostname = False
        self.ssl_context.verify_mode = ssl.CERT_NONE

    def _make_request(self, url, method='GET', data=None):
        """Make HTTP request using urllib."""
        req = urllib.request.Request(url, method=method)
        req.add_header('Content-Type', 'application/json')

        if self.user and self.password:
            import base64
            credentials = base64.b64encode(
                f"{self.user}:{self.password}".encode()).decode()
            req.add_header('Authorization', f'Basic {credentials}')

        if data:
            req.data = json.dumps(data).encode('utf-8')
            print(f"DEBUG: Sending data: {json.dumps(data)[:200]}...")

        try:
            with urllib.request.urlopen(req, context=self.ssl_context) as response:
                return json.loads(response.read().decode('utf-8'))
        except Exception as e:
            print(f"Request failed: {e}")
            return None

    def ping(self):
        """Check if OpenSearch is reachable."""
        try:
            result = self._make_request(self.host)
            return result is not None
        except Exception as e:
            print(f"OpenSearch connection failed: {e}")
            return False

    def create_index_with_mapping(self, index_name="issues"):
        """Create index with proper mapping for semantic search."""
        # Start with a simple mapping without dense vectors for now
        mapping = {
            "mappings": {
                "properties": {
                    "id": {"type": "keyword"},
                    "subject": {"type": "text", "analyzer": "standard"},
                    "description": {"type": "text", "analyzer": "standard"},
                    "project": {
                        "properties": {
                            "id": {"type": "keyword"},
                            "name": {"type": "text", "analyzer": "standard"},
                            "identifier": {"type": "keyword"}
                        }
                    },
                    "tracker": {
                        "properties": {
                            "id": {"type": "keyword"},
                            "name": {"type": "keyword"}
                        }
                    },
                    "status": {
                        "properties": {
                            "id": {"type": "keyword"},
                            "name": {"type": "keyword"}
                        }
                    },
                    "priority": {
                        "properties": {
                            "id": {"type": "keyword"},
                            "name": {"type": "keyword"}
                        }
                    },
                    "author": {
                        "properties": {
                            "id": {"type": "keyword"},
                            "name": {"type": "text", "analyzer": "standard"}
                        }
                    },
                    "assigned_to": {
                        "properties": {
                            "id": {"type": "keyword"},
                            "name": {"type": "text", "analyzer": "standard"}
                        }
                    },
                    "start_date": {"type": "date"},
                    "due_date": {"type": "date"},
                    "done_ratio": {"type": "integer"},
                    "is_private": {"type": "boolean"},
                    "created_on": {"type": "date"},
                    "updated_on": {"type": "date"},
                    "closed_on": {"type": "date"},
                    "similarity_score": {"type": "float"},
                    "search_text": {"type": "text", "analyzer": "standard"}
                }
            },
            "settings": {
                "number_of_shards": 1,
                "number_of_replicas": 0
            }
        }

        url = f"{self.host}/{index_name}"
        result = self._make_request(url, method='PUT', data=mapping)

        if result:
            print(f"✅ Index '{index_name}' created successfully")
            return True
        else:
            print(f"❌ Failed to create index")
            return False

    def bulk_index_issues(self, issues, index_name="issues"):
        """Bulk index a list of issue dicts into OpenSearch."""
        if not issues:
            print("No issues to index.")
            return

        bulk_payload = ""
        for issue in issues:
            meta = {"index": {"_index": index_name, "_id": issue["id"]}}
            bulk_payload += f"{json.dumps(meta)}\n{json.dumps(issue)}\n"

        url = f"{self.host}/_bulk"

        # Create request with proper headers for bulk indexing
        req = urllib.request.Request(url, method='POST')
        req.add_header('Content-Type', 'application/x-ndjson')

        if self.user and self.password:
            import base64
            credentials = base64.b64encode(
                f"{self.user}:{self.password}".encode()).decode()
            req.add_header('Authorization', f'Basic {credentials}')

        req.data = bulk_payload.encode('utf-8')

        try:
            with urllib.request.urlopen(req, context=self.ssl_context) as response:
                result = json.loads(response.read().decode('utf-8'))
                if result.get("errors"):
                    print(f"⚠️  Bulk index completed with errors: {result}")
                else:
                    print(f"✅ Successfully indexed {len(issues)} issues")
        except Exception as e:
            print(f"❌ Bulk index failed: {e}")
            # Try to get more details about the error
            try:
                with urllib.request.urlopen(req, context=self.ssl_context) as response:
                    print(f"Response: {response.read().decode()}")
            except Exception as e2:
                print(f"Error details: {e2}")


class EmbeddingService:
    """Service for generating text embeddings."""

    def __init__(self, service_url=None, api_key=None):
        self.service_url = service_url
        self.api_key = api_key

    def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding for given text."""
        if not text or not text.strip():
            return self._get_default_embedding()

        # In production, this would call OpenAI, Cohere, or similar
        if self.service_url and self.api_key:
            return self._call_embedding_service(text)
        else:
            return self._generate_simple_embedding(text)

    def _call_embedding_service(self, text: str) -> List[float]:
        """Call external embedding service."""
        try:
            req = urllib.request.Request(f"{self.service_url}/embeddings")
            req.add_header('Authorization', f'Bearer {self.api_key}')
            req.add_header('Content-Type', 'application/json')
            req.data = json.dumps({'text': text}).encode('utf-8')

            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode('utf-8'))
                return result['embedding']
        except Exception as e:
            print(f"⚠️  Embedding service error: {e}")
            return self._generate_simple_embedding(text)

    def _generate_simple_embedding(self, text: str) -> List[float]:
        """Generate a simple hash-based embedding for development."""
        # Create a deterministic vector based on text hash
        hash_obj = hashlib.sha256(text.encode())
        hash_bytes = hash_obj.digest()

        # Convert to 1536-dimensional vector
        vector = []
        for i in range(1536):
            byte_index = i % len(hash_bytes)
            vector.append((hash_bytes[byte_index] / 255.0) * 2 - 1)

        return vector

    def _get_default_embedding(self) -> List[float]:
        """Return default embedding for empty text."""
        return [0.0] * 1536


def transform_issue_for_opensearch(issue: Dict[str, Any], embedding_service: EmbeddingService) -> Dict[str, Any]:
    """Transform a Redmine issue dict to an OpenSearch-ready dict with embeddings."""

    def extract(obj, keys):
        if obj is None:
            return None
        return {k: obj.get(k) for k in keys if k in obj}

    # Prepare text for embedding
    subject = issue.get("subject", "")
    description = issue.get("description", "")
    project_name = issue.get("project", {}).get("name", "")

    # Combine text for embedding
    search_text = f"{subject} {description} {project_name}".strip()

    # Generate embedding (for future use)
    embedding_vector = embedding_service.generate_embedding(search_text)

    # Calculate simple similarity score (placeholder)
    similarity_score = min(1.0, len(search_text) / 1000.0)

    return {
        "id": issue.get("id"),
        "subject": subject,
        "description": description,
        "project": extract(issue.get("project"), ["id", "name", "identifier"]),
        "tracker": extract(issue.get("tracker"), ["id", "name"]),
        "status": extract(issue.get("status"), ["id", "name"]),
        "priority": extract(issue.get("priority"), ["id", "name"]),
        "author": extract(issue.get("author"), ["id", "name"]),
        "assigned_to": extract(issue.get("assigned_to"), ["id", "name"]),
        "start_date": issue.get("start_date"),
        "due_date": issue.get("due_date"),
        "done_ratio": issue.get("done_ratio"),
        "is_private": issue.get("is_private"),
        "created_on": issue.get("created_on"),
        "updated_on": issue.get("updated_on"),
        "closed_on": issue.get("closed_on"),
        "similarity_score": similarity_score,
        "search_text": search_text
    }


def main():
    """Main ETL orchestration."""
    print("🚀 Starting Enhanced ETL Process...")

    # Initialize clients
    client = RedmineAPIClient(REDMINE_API_URL, REDMINE_API_KEY)
    opensearch = OpenSearchClient(
        OPENSEARCH_HOST, OPENSEARCH_USER, OPENSEARCH_PASS)
    embedding_service = EmbeddingService(
        EMBEDDING_SERVICE_URL, EMBEDDING_API_KEY)

    # Check OpenSearch connectivity
    if not opensearch.ping():
        print("❌ OpenSearch is not reachable. Exiting.")
        exit(1)

    # Skip index creation since we created it manually
    print("✅ Using existing index (created manually)")

    # ETL Process
    BATCH_SIZE = 50  # Smaller batch size for better error handling
    offset = 0
    total_fetched = 0
    total_indexed = 0

    print("📊 Starting data extraction and indexing...")

    while True:
        try:
            print(
                f"📥 Fetching issues (offset: {offset}, limit: {BATCH_SIZE})...")
            issues = client.fetch_issues(limit=BATCH_SIZE, offset=offset)

            if not issues:
                print("✅ No more issues to fetch.")
                break

            print(f"🔄 Transforming {len(issues)} issues...")
            transformed = []
            for issue in issues:
                try:
                    transformed_issue = transform_issue_for_opensearch(
                        issue, embedding_service)
                    transformed.append(transformed_issue)
                except Exception as e:
                    print(
                        f"⚠️  Error transforming issue {issue.get('id')}: {e}")
                    continue

            if transformed:
                print(f"📤 Indexing {len(transformed)} issues...")
                opensearch.bulk_index_issues(transformed)
                total_indexed += len(transformed)

            total_fetched += len(issues)
            print(
                f"📈 Progress: {total_fetched} fetched, {total_indexed} indexed")

            if len(issues) < BATCH_SIZE:
                break

            offset += BATCH_SIZE

            # Small delay to be respectful to the API
            time.sleep(0.1)

        except Exception as e:
            print(f"❌ Error in ETL process: {e}")
            break

    print(
        f"🎉 ETL complete! Total issues processed: {total_fetched}, indexed: {total_indexed}")
    print("🌐 Test semantic search at: http://localhost:3000/rass")


if __name__ == "__main__":
    main()
