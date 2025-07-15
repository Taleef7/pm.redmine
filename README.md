# Redmine Monorepo

A comprehensive monorepo setup for Redmine development and testing with Docker support.

## Overview

This repository contains:

- **Redmine core** as a submodule (locked to 6.0-stable)
- **Plugin submodules** in the `plugins/` directory
- **Docker infrastructure** for easy development and testing
- **Automated workflows** for continuous integration

## Quick Start

1. **Clone the repository with submodules**:

   ```bash
   git clone --recursive https://github.com/mieweb/pm.redmine.com.git
   cd pm.redmine.com
   ```

2. **Configure Environment Secrets**:

   - Create a `.env` file in the root directory with your environment variables:

   ```bash
   cp .env.example .env
   ```

   - Generate and add the Secret Key since this version of Redmine looks for a secret_token.rb file:

   ```bash
   echo "RedmineApp::Application.config.secret_key_base = '$(docker-compose run --rm redmine bundle exec ruby -rsecurerandom -e "print SecureRandom.hex(64)")'" > redmine/config/initializers/secret_token.rb
   ```

   Note: This command must be run before the first build, but you only ever need to run it once.

3. **Build the Docker Image**:

   ```bash
   docker-compose build
   ```

4. **Run One-Time Database Setup**:

   ```bash
   # First, run the core Redmine migrations
   docker-compose run --rm redmine bundle exec rake db:migrate RAILS_ENV=production

   # Second, run the migrations for any plugins
   docker-compose run --rm redmine bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

5. **Start the Application**:

   ```bash
   docker-compose up
   ```

6. **Access Redmine**:

   - Open your browser and go to [http://localhost:3000](http://localhost:3000).
   - Default credentials: `admin` / `admin`

## Daily Development Workflow

After you have completed the one-time setup, your daily workflow is simple:

- To start the server: `docker-compose up`

- To stop the server: Press `Ctrl+C` in the terminal where it's running.

## Repository Structure

```

├── redmine/ # Redmine core (submodule)
├── plugins/ # Plugin submodules
│ ├── additionals/ # AlphaNodes additionals plugin
│ └── clipboard_image_paste/ # Clipboard image paste plugin
├── config/
│ └── database.yml # Database configuration
├── docker-compose.yml # Docker Compose configuration
├── docker-compose.prebuilt.yml # Alternative using prebuilt image
├── Dockerfile # Redmine container definition
├── Dockerfile.prebuilt # Alternative Dockerfile
├── init-plugins.sh # Plugin initialization script
├── test-structure.sh # Structure validation script
└── .github/workflows/ # CI/CD workflows

```

## Included Plugins

### 1. Additionals

- **Repository**: [AlphaNodes/additionals](https://github.com/AlphaNodes/additionals)
- **Description**: Provides additional features and enhancements for Redmine

### 2. Clipboard Image Paste

- **Repository**: [peclik/clipboard_image_paste](https://github.com/peclik/clipboard_image_paste)
- **Description**: Allows pasting images directly from clipboard into Redmine

## Configuration

### Environment Variables

The following environment variables can be used to customize the setup:

#### Database Configuration

- `MYSQL_ROOT_PASSWORD` (default: `redmine_root`)
- `MYSQL_DATABASE` (default: `redmine`)
- `MYSQL_USER` (default: `redmine`)
- `MYSQL_PASSWORD` (default: `redmine`)

#### Redmine Configuration

- `RAILS_ENV` (default: `production`)
- `REDMINE_DB_MYSQL` (default: `db`)
- `REDMINE_DB_PORT` (default: `3306`)
- `REDMINE_DB_DATABASE` (default: `redmine`)
- `REDMINE_DB_USERNAME` (default: `redmine`)
- `REDMINE_DB_PASSWORD` (default: `redmine`)

### Example with Custom Environment

```bash
# Create .env file
cat > .env << EOF
MYSQL_ROOT_PASSWORD=my_secure_root_password
MYSQL_PASSWORD=my_secure_password
RAILS_ENV=development
EOF

# Start with custom environment
docker-compose up
```

## Development Workflow

## Development Workflow

### Alternative Setup (if Docker build fails)

If you encounter SSL issues during Docker build, you can set up Redmine manually:

1. **Install dependencies locally**:

   ```bash
   # Install Ruby, MariaDB/MySQL locally
   # Ubuntu/Debian:
   sudo apt-get install ruby-dev mariadb-server libmariadb-dev

   # macOS:
   brew install ruby mariadb
   ```

2. **Set up database**:

   ```bash
   # Start MariaDB
   sudo systemctl start mariadb
   # or on macOS: brew services start mariadb

   # Create database and user
   mysql -u root -p
   CREATE DATABASE redmine CHARACTER SET utf8mb4;
   CREATE USER 'redmine'@'localhost' IDENTIFIED BY 'redmine';
   GRANT ALL PRIVILEGES ON redmine.* TO 'redmine'@'localhost';
   FLUSH PRIVILEGES;
   ```

3. **Configure and run Redmine**:
   ```bash
   cd redmine
   bundle install --without development test
   bundle exec rake generate_secret_token
   RAILS_ENV=production bundle exec rake db:migrate
   RAILS_ENV=production bundle exec rails server
   ```

### Adding New Plugins

1. **Add plugin as submodule**:

   ```bash
   git submodule add https://github.com/user/plugin_name.git plugins/plugin_name
   ```

2. **Rebuild and restart**:
   ```bash
   docker-compose down
   docker-compose build
   docker-compose up
   ```

### Updating Redmine or Plugins

1. **Update submodules**:

   ```bash
   git submodule update --remote
   ```

2. **Rebuild containers**:
   ```bash
   docker-compose build --no-cache
   docker-compose up
   ```

### Plugin Development

- Plugins are mounted as read-only from the host
- The `init-plugins.sh` script creates symlinks in the Redmine plugins directory
- Any changes to plugin files will be reflected after container restart

## Services

### Redmine

- **Port**: 3000
- **URL**: http://localhost:3000
- **Environment**: Production (configurable)

### MariaDB Database

- **Port**: 3306
- **Database**: redmine
- **Username**: redmine
- **Password**: redmine (configurable)

## Testing

The repository includes a GitHub Actions workflow that:

1. Builds the Docker image
2. Starts the services
3. Tests Redmine accessibility
4. Provides detailed logs on failure

### Manual Testing

```bash
# Build and test locally
docker-compose up --build

# Test database connection
docker-compose exec redmine bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name"

# Test plugin loading
docker-compose exec redmine bundle exec rails runner "puts Redmine::Plugin.all.map(&:id)"
```

## Troubleshooting

### Common Issues

1. **SSL Certificate Issues During Build**:
   If you encounter SSL certificate errors during Docker build:

   ```bash
   # Option 1: Use HTTP for RubyGems (development only)
   # Edit redmine/Gemfile and change the source line to:
   # source 'http://rubygems.org'

   # Option 2: Build with network mode
   docker build --network=host -t redmine-monorepo .

   # Option 3: Use Docker BuildKit with SSL fix
   DOCKER_BUILDKIT=1 docker build -t redmine-monorepo .
   ```

2. **Database connection issues**:

   ```bash
   # Check database logs
   docker-compose logs db

   # Verify database is running
   docker-compose exec db mysql -u redmine -p -e "SHOW DATABASES;"
   ```

3. **Plugin not loading**:

   ```bash
   # Check plugin symlinks
   docker-compose exec redmine ls -la plugins/

   # Verify plugin structure
   docker-compose exec redmine find plugins/ -name "init.rb"
   ```

4. **Port conflicts**:
   ```bash
   # Use different ports
   REDMINE_PORT=3001 MYSQL_PORT=3307 docker-compose up
   ```

### Logs and Debugging

```bash
# View all logs
docker-compose logs

# Follow specific service logs
docker-compose logs -f redmine

# Access Redmine container
docker-compose exec redmine bash
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or update plugins/configurations
4. Test with `docker-compose up`
5. Submit a pull request

## License

This monorepo setup is provided as-is. Individual components (Redmine core and plugins) maintain their respective licenses.

- **Redmine**: GNU General Public License v2.0
- **Plugins**: See individual plugin repositories for license information
