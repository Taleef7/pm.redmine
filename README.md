# Redmine Semantic Search with OpenSearch

A comprehensive Redmine setup with semantic search capabilities using OpenSearch, ETL pipeline, and test data generation.

## Overview

This repository contains:

- **Redmine core** as a submodule (locked to 6.0-stable)
- **Semantic search plugin** (RASS) that queries OpenSearch directly
- **ETL pipeline** for indexing Redmine data into OpenSearch
- **Docker infrastructure** with Redmine, MariaDB, and OpenSearch
- **Test data generation** scripts for development and testing
- **Automated workflows** for continuous integration

## Features

### 🔍 Semantic Search
- Full-text search across all Redmine issues
- Search in subject, description, project, status, priority, and more
- Fuzzy matching and highlighting
- Real-time search results with scoring

### 📊 ETL Pipeline
- Automated data extraction from Redmine REST API
- Transformation and cleaning of issue data
- Bulk indexing into OpenSearch
- Configurable batch processing

### 🧪 Test Data Generation
- Rails console scripts for creating test projects and issues
- Diverse issue types (software, marketing, HR)
- Configurable data volume for testing

## Quick Start

1. **Clone the repository with submodules**:

   ```bash
   git clone --recursive https://github.com/mieweb/pm.redmine.com.git
   cd pm.redmine.com
   ```

2. **Configure Environment Secrets**:

   ```bash
   # Create .env file with required variables
   cat > .env << EOF
   MYSQL_ROOT_PASSWORD=redmine_root
   MYSQL_DATABASE=redmine
   MYSQL_USER=redmine
   MYSQL_PASSWORD=redmine
   REDMINE_SECRET_KEY_BASE=$(openssl rand -hex 64)
   REDMINE_API_KEY=your_api_key_here
   OPENSEARCH_USER=admin
   OPENSEARCH_PASS=adminpassword123
   OPENSEARCH_INITIAL_ADMIN_PASSWORD=adminpassword123
   EOF
   ```

3. **Generate Secret Key**:

   ```bash
   echo "RedmineApp::Application.config.secret_key_base = '$(docker-compose run --rm redmine bundle exec ruby -rsecurerandom -e "print SecureRandom.hex(64)")'" > redmine/config/initializers/secret_token.rb
   ```

4. **Build and Start Services**:

   ```bash
   docker-compose build
   docker-compose up -d
   ```

5. **Run Database Setup**:

   ```bash
   # Core Redmine migrations
   docker-compose run --rm redmine bundle exec rake db:migrate RAILS_ENV=production

   # Plugin migrations
   docker-compose run --rm redmine bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

6. **Generate API Key** (if not set in .env):

   ```bash
   docker-compose exec redmine bundle exec rails console
   # In console:
   user = User.find_by(login: 'admin')
   token = Token.create!(user: user, action: 'api')
   puts "API Key: #{token.value}"
   exit
   ```

7. **Generate Test Data**:

   ```bash
   # Copy test data script to container
   docker cp generate-test-data-rails.rb redmine:/tmp/
   
   # Run the script
   docker-compose exec redmine bundle exec rails runner /tmp/generate-test-data-rails.rb
   ```

8. **Run ETL Pipeline**:

   ```bash
   # Run ETL to index data into OpenSearch
   docker-compose --profile etl run --rm etl python /app/etl_script.py
   ```

9. **Access Redmine**:

   - Open [http://localhost:3000](http://localhost:3000)
   - Default credentials: `admin` / `admin`
   - Navigate to "RASS" in the top menu for semantic search

## Repository Structure

```
├── redmine/                    # Redmine core (submodule)
├── plugins/                    # Plugin submodules
│   ├── redmine_rass_plugin/   # Semantic search plugin
│   ├── additionals/           # AlphaNodes additionals plugin
│   └── clipboard_image_paste/ # Clipboard image paste plugin
├── etl/                       # ETL pipeline
│   └── etl_script.py         # Main ETL script
├── config/
│   └── database.yml          # Database configuration
├── docker-compose.yml         # Docker Compose configuration
├── Dockerfile                 # Redmine container definition
├── Dockerfile.etl            # ETL container definition
├── init-plugins.sh           # Plugin initialization script
├── generate-test-data-rails.rb # Test data generation
├── run-etl.sh                # ETL execution script
├── test-setup.sh             # Test environment setup
└── .github/workflows/        # CI/CD workflows
```

## Services

### Redmine
- **Port**: 3000
- **URL**: http://localhost:3000
- **Features**: Core issue tracking with semantic search plugin

### MariaDB Database
- **Port**: 3306
- **Database**: redmine
- **Username**: redmine
- **Password**: redmine (configurable)

### OpenSearch
- **Port**: 9200
- **Version**: 2.14.0
- **Purpose**: Semantic search index
- **Security**: Disabled for development

### ETL Service
- **Profile**: etl (runs on demand)
- **Purpose**: Index Redmine data into OpenSearch
- **Dependencies**: Redmine API, OpenSearch

## Semantic Search Plugin

The RASS plugin provides semantic search capabilities:

### Features
- Full-text search across all issue fields
- Fuzzy matching for typos and variations
- Result highlighting
- Configurable search weights
- Real-time results

### Usage
1. Navigate to "RASS" in the top menu
2. Enter your search query
3. View results with highlighting and scoring
4. Click on issue numbers to view full details

### Search Fields
- Subject (highest weight)
- Description (medium weight)
- Project name (medium weight)
- Status, priority, author, assignee
- Custom fields and attachments

## ETL Pipeline

The ETL pipeline extracts data from Redmine and indexes it into OpenSearch:

### Configuration
- **Batch Size**: 100 issues per batch
- **API Endpoint**: Redmine REST API
- **Index Name**: `issues`
- **Authentication**: API key

### Running ETL
```bash
# Run ETL pipeline
docker-compose --profile etl run --rm etl python /app/etl_script.py

# Or use the convenience script
./run-etl.sh
```

### Data Transformation
The ETL script transforms Redmine issues into OpenSearch documents:
- Maps all issue fields
- Handles nested objects (project, status, etc.)
- Preserves custom fields and attachments
- Maintains data relationships

## Test Data Generation

Generate test data for development and testing:

### Rails Console Script
```bash
# Generate 30 diverse issues
docker-compose exec redmine bundle exec rails runner generate-test-data-rails.rb
```

### Test Data Types
- Software development issues
- Marketing and content tasks
- HR and administrative tasks
- Various priorities and statuses
- Different projects and assignees

## Development Workflow

### Adding New Plugins
1. Add plugin as submodule:
   ```bash
   git submodule add https://github.com/user/plugin_name.git plugins/plugin_name
   ```

2. Rebuild and restart:
   ```bash
   docker-compose down
   docker-compose build
   docker-compose up
   ```

### Updating Redmine or Plugins
1. Update submodules:
   ```bash
   git submodule update --remote
   ```

2. Rebuild containers:
   ```bash
   docker-compose build --no-cache
   docker-compose up
   ```

### Plugin Development
- Plugins are mounted as read-only from the host
- The `init-plugins.sh` script creates symlinks
- Changes reflect after container restart

## Configuration

### Environment Variables

#### Database Configuration
- `MYSQL_ROOT_PASSWORD` (default: `redmine_root`)
- `MYSQL_DATABASE` (default: `redmine`)
- `MYSQL_USER` (default: `redmine`)
- `MYSQL_PASSWORD` (default: `redmine`)

#### Redmine Configuration
- `RAILS_ENV` (default: `production`)
- `REDMINE_SECRET_KEY_BASE` (required)
- `REDMINE_API_KEY` (required for ETL)

#### OpenSearch Configuration
- `OPENSEARCH_HOST` (default: `http://opensearch:9200`)
- `OPENSEARCH_USER` (default: `admin`)
- `OPENSEARCH_PASS` (default: `adminpassword123`)
- `OPENSEARCH_INITIAL_ADMIN_PASSWORD` (required for OpenSearch 2.12+; default: `adminpassword123`)

### Example .env File
```bash
MYSQL_ROOT_PASSWORD=my_secure_root_password
MYSQL_PASSWORD=my_secure_password
REDMINE_SECRET_KEY_BASE=your_secret_key_here
REDMINE_API_KEY=your_api_key_here
RAILS_ENV=production
```

## Testing

### Manual Testing
```bash
# Test Redmine accessibility
curl http://localhost:3000

# Test OpenSearch
curl http://localhost:9200

# Test semantic search
curl "http://localhost:3000/rass?q=bug"

# Check indexed data
curl "http://localhost:9200/issues/_search?q=*"
```

### Automated Testing
The repository includes GitHub Actions workflows that:
1. Build Docker images
2. Start services
3. Test Redmine accessibility
4. Verify plugin functionality

## Troubleshooting

### Common Issues

1. **API Key Not Found**:
   ```bash
   # Generate new API key
   docker-compose exec redmine bundle exec rails console
   user = User.find_by(login: 'admin')
   Token.where(user: user, action: 'api').destroy_all
   token = Token.create!(user: user, action: 'api')
   puts "New API Key: #{token.value}"
   ```

2. **OpenSearch Connection Issues**:
   ```bash
   # Check OpenSearch health
   curl http://localhost:9200/_cluster/health
   
   # Check service logs
   docker-compose logs opensearch
   ```

3. **ETL Pipeline Errors**:
   ```bash
   # Check ETL logs
   docker-compose --profile etl run --rm etl python /app/etl_script.py

   # Verify API key in .env
   cat .env | grep REDMINE_API_KEY
   ```

4. **Plugin Not Loading**:
   ```bash
   # Check plugin symlinks
   docker-compose exec redmine ls -la plugins/

   # Verify plugin structure
   docker-compose exec redmine find plugins/ -name "init.rb"
   ```

### Logs and Debugging
```bash
# View all logs
docker-compose logs

# Follow specific service logs
docker-compose logs -f redmine
docker-compose logs -f opensearch

# Access containers
docker-compose exec redmine bash
docker-compose exec opensearch bash
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or update plugins/configurations
4. Test with `docker-compose up`
5. Submit a pull request

## License

This monorepo setup is provided as-is. Individual components maintain their respective licenses:

- **Redmine**: GNU General Public License v2.0
- **Plugins**: See individual plugin repositories
- **OpenSearch**: Apache License 2.0
