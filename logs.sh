#!/bin/sh

log_debug () {
  if [ ! -z "$DEBUG" ]; then
    echo >&2 "[ DEBUG ]" $1
  fi
}

log_info () {
  echo "[ INFO ]" $1
}
