FROM ruby:3.1

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    default-mysql-client \
    libmariadb-dev \
    imagemagick \
    libmagickwand-dev \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Set working directory
WORKDIR /usr/src/redmine

# Copy Redmine source code
COPY redmine/ .

# Copy database configuration
COPY config/database.yml config/database.yml

# COPY PLUGINS FIRST!
COPY plugins/ /usr/src/redmine/plugins/

# Add required web server gem
RUN echo 'gem "puma"' >> Gemfile

# NOW, install all gems from Redmine core AND all plugins in one go
RUN bundle install

# Create directories
RUN mkdir -p tmp tmp/pdf public/plugin_assets

# Set permissions
RUN chown -R nobody:nogroup files log tmp public public/plugin_assets plugins config db

# Expose port
EXPOSE 3000

# Switch to nobody user
USER nobody

# Start Redmine
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]