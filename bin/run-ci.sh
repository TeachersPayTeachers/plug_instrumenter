#!/bin/bash
set -euxo pipefail

mix local.rebar --force
mix local.hex --force
MIX_ENV="test" mix ci
