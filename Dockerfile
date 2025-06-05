FROM ruby:3.1

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    default-mysql-client \
    libmariadb-dev \
    imagemagick \
    libmagickwand-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /usr/src/redmine

# Copy Redmine source code
COPY redmine/ .

# Copy database configuration
COPY config/database.yml config/database.yml

# Install gems
RUN bundle install --without development test

# Create directories
RUN mkdir -p tmp tmp/pdf public/plugin_assets

# Set permissions
RUN chown -R nobody:nogroup files log tmp public/plugin_assets

# Expose port
EXPOSE 3000

# Switch to nobody user
USER nobody

# Start Redmine
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]