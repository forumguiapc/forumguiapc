FROM ruby:3.4.7-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    RAILS_ENV=production \
    BUNDLE_WITHOUT=development:test

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      build-essential \
      git \
      curl \
      ca-certificates \
      gnupg \
      pkg-config \
      libpq-dev \
      postgresql-client \
      libxml2-dev \
      libxslt1-dev \
      zlib1g-dev \
      libssl-dev \
      libyaml-dev \
      libffi-dev \
      imagemagick \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && corepack enable \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

# Discourse's build scripts (assemble_ember_build.rb, version lookups) shell
# out to git. We exclude .git from the build context (909MB, full fork
# history) so we synthesize a minimal valid repo matching the copied tree.
RUN git init -q \
    && git config user.email "build@localhost" \
    && git config user.name "Docker Build" \
    && git add -A \
    && git commit -q -m "docker build snapshot" --allow-empty

RUN bundle install --jobs 4 --retry 3

RUN corepack prepare pnpm@10.28.0 --activate \
    && pnpm install --frozen-lockfile

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
