# Redmine Monorepo

A comprehensive monorepo setup for Redmine development and testing with Docker support.

## Overview

This repository contains:
- **Redmine core** as a submodule (locked to 5.1-stable)
- **Plugin submodules** in the `plugins/` directory
- **Docker infrastructure** for easy development and testing
- **Automated workflows** for continuous integration

## Quick Start

1. **Clone the repository with submodules**:
   ```bash
   git clone --recursive https://github.com/mieweb/pm.redmine.com.git
   cd pm.redmine.com
   ```

2. **Start the development environment**:
   ```bash
   docker-compose up
   ```

3. **Access Redmine**:
   - Open your browser to [http://localhost:3000](http://localhost:3000)
   - Default admin credentials: `admin` / `admin`

## Repository Structure

```
├── redmine/                 # Redmine core (submodule)
├── plugins/                 # Plugin submodules
│   ├── additionals/         # AlphaNodes additionals plugin
│   └── clipboard_image_paste/ # Clipboard image paste plugin
├── config/
│   └── database.yml         # Database configuration
├── docker-compose.yml       # Docker Compose configuration
├── Dockerfile              # Redmine container definition
├── init-plugins.sh         # Plugin initialization script
└── .github/workflows/      # CI/CD workflows
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

1. **Database connection issues**:
   ```bash
   # Check database logs
   docker-compose logs db
   
   # Verify database is running
   docker-compose exec db mysql -u redmine -p -e "SHOW DATABASES;"
   ```

2. **Plugin not loading**:
   ```bash
   # Check plugin symlinks
   docker-compose exec redmine ls -la plugins/
   
   # Verify plugin structure
   docker-compose exec redmine find plugins/ -name "init.rb"
   ```

3. **Port conflicts**:
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