#!/bin/sh
set -e

if [ "$PROCESS_TYPE" = "worker" ]; then
  echo "==> Starting Sidekiq worker"
  exec bundle exec sidekiq
fi

echo "==> Running database migrations"
bundle exec rake db:migrate

echo "==> Precompiling assets"
bundle exec rake assets:precompile

echo "==> Starting Puma on port ${PORT:-3000}"
exec bundle exec puma -e production -p "${PORT:-3000}" -b "tcp://0.0.0.0:${PORT:-3000}"
