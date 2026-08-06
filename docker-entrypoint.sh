#!/bin/sh
set -e

echo "==> Testing DB connectivity"
bundle exec ruby -e '
require "pg"
begin
  conn = PG.connect(
    host: ENV["DISCOURSE_DB_HOST"],
    port: ENV["DISCOURSE_DB_PORT"],
    dbname: ENV["DISCOURSE_DB_NAME"],
    user: ENV["DISCOURSE_DB_USERNAME"],
    password: ENV["DISCOURSE_DB_PASSWORD"],
    connect_timeout: 10,
    sslmode: "require"
  )
  conn.exec("select 1")
  puts "DB OK"
  conn.close
rescue => e
  puts "DB FAILED: #{e.class}: #{e.message}"
  exit 1
end
'

echo "==> Testing Redis connectivity"
bundle exec ruby -e '
require "redis"
begin
  r = Redis.new(
    host: ENV["DISCOURSE_REDIS_HOST"],
    port: ENV["DISCOURSE_REDIS_PORT"],
    password: ENV["DISCOURSE_REDIS_PASSWORD"],
    timeout: 10
  )
  puts "REDIS PING: #{r.ping}"
rescue => e
  puts "REDIS FAILED: #{e.class}: #{e.message}"
  exit 1
end
'

if [ "$PROCESS_TYPE" = "worker" ]; then
  echo "==> Starting Sidekiq worker"
  exec bundle exec sidekiq
fi

echo "==> Testing full Rails boot (bounded to 120s)"
set +e
timeout 120 bundle exec bin/rails runner "puts 'RAILS BOOT OK'"
BOOT_EXIT=$?
set -e
if [ "$BOOT_EXIT" -eq 124 ]; then
  echo "RAILS BOOT TIMED OUT after 120s"
  exit 1
elif [ "$BOOT_EXIT" -ne 0 ]; then
  echo "RAILS BOOT FAILED with exit code $BOOT_EXIT"
  exit 1
fi

echo "==> Running database migrations (bounded to 1800s)"
set +e
timeout 1800 bundle exec rake db:migrate
MIGRATE_EXIT=$?
set -e
if [ "$MIGRATE_EXIT" -eq 124 ]; then
  echo "MIGRATE TIMED OUT after 1800s"
  exit 1
elif [ "$MIGRATE_EXIT" -ne 0 ]; then
  echo "MIGRATE FAILED with exit code $MIGRATE_EXIT"
  exit 1
fi

echo "==> Precompiling assets"
bundle exec rake assets:precompile

echo "==> Starting Puma on port ${PORT:-3000}"
exec bundle exec puma -e production -t 8:32 -w 2 --preload -b "tcp://0.0.0.0:${PORT:-3000}"
