#!/bin/bash
set -euxo pipefail


mix run samples/plug_instrumenter.exs
mix run samples/pipeline_instrumenter.exs
