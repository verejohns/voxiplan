#!/bin/bash

echo "Running Release Tasks"

export TESTVAR="my value"

if [ "$HEROKU_PARENT_APP_NAME" == "" ]; then
  echo "Migrating DB schema"
  bundle exec rake db:migrate

  echo "Migrating DATA"
  bundle exec rake tasks:migrate
fi

echo "Done running release-tasks.sh"
