#!/bin/bash

echo "Running postdeploy script"
echo "The postdeploy script is run once, after the app is created and not on subsequent deploys to the app"
# https://devcenter.heroku.com/articles/app-json-schema#scripts

echo "TESTVAR: ($TESTVAR)"

echo "Copying DB"
pg_dump $DEV_DATABASE_URL | psql $DATABASE_URL

echo "Migrating DB"
bundle exec rake db:migrate

echo "Updating DATA"
bundle exec rake tasks:migrate
