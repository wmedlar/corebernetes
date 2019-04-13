#!/bin/sh -e

# $COMPOSE_FILE is used by docker-compose as an alternative to -f
# we don't want to shadow it here in the even that it's set, so prefix with _
_COMPOSE_FILE="$(git rev-parse --show-toplevel)/docker-compose.yaml"

for service in $(docker-compose -f $_COMPOSE_FILE config --services); do
    alias "$service"="docker-compose -f $_COMPOSE_FILE run --rm $service"

    # print our alias to stderr so you can tell we've done something
    alias "$service" 1>&2
done
