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

echo "==> Running database migrations"
bundle exec rake db:migrate

echo "==> Precompiling assets"
bundle exec rake assets:precompile

echo "==> Starting Puma on port ${PORT:-3000}"
exec bundle exec puma -e production -p "${PORT:-3000}" -b "tcp://0.0.0.0:${PORT:-3000}"
