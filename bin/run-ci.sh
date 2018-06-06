#!/bin/bash
set -euxo pipefail

MIX_ENV="test" mix ci
