# PlugInstrumenter

[![Hex pm](http://img.shields.io/hexpm/v/plug_instrumenter.svg?style=flat)](https://hex.pm/packages/plug_instrumenter)
[![Inline docs](http://inch-ci.org/github/TeachersPayTeachers/plug_instrumenter.svg)](http://inch-ci.org/github/TeachersPayTeachers/plug_instrumenter)
[![Build Status](https://travis-ci.org/TeachersPayTeachers/plug_instrumenter.svg?branch=master)](https://travis-ci.org/TeachersPayTeachers/plug_instrumenter)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A simple plug that can be used to wrap plugs with an instrumentation callback.
`PipelineInstrumenter` can be used in a similar fashion to `Plug.Builder` to
instrument a plug pipeline.

Goals:

- Simple
- Flexible

**NOTE**: `PipelineInstrumenter` does not work with function plugs.

## Installation

The package can be installed by adding `plug_instrumenter` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:plug_instrumenter, "~> 0.1.2"}
  ]
end
```

## Usage

### PlugInstrumenter

```elixir
plug PlugInstrumenter, plug: MyPlug, opts: [my_opt: :somevalue]
```

### PipelineInstrumenter

```elixir
defmodule MyApp.Pipeline do
  use PipelineInstrumenter, exclude: [MyApp.Router]

  plug MyPlug, my_opt: :somevalue

  plug MyApp.Router
end
```

### With Phoenix

```elixir
defmodule MyApp.Endpoint.Plugs do
  use PipelineInstrumenter, exclude: [MyApp.Router]

  plug MyPlug, my_opt: :somevalue

  plug MyApp.Router
end

defmodule MyApp.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # unless you really want to instrument the code reloader :)
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug MyApp.Endpoint.Plugs
end
```

## Default Configuration

The default configuration is as follows:

```elixir
config :plug_instrumenter,
  callback: {PlugInstrumenter, :default_callback},
  now: {:erlang, :monotonic_time, [:microsecond]},
  name: MyPlug
```

More information is available in the
[documentation](https://hex.pm/packages/plug_instrumenter).
