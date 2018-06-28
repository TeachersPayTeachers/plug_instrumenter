# PlugInstrumenter

A simple plug that can be used to wrap plugs with an instrumentation callback.
There is also `PipelineInstrumenter` that can be used in a similar fashion to
`Plug.Builder` to instrument a plug pipeline.

*NOTE* `PipelineInstrumenter` does not work with function plugs at this time.

## Installation

The package can be installed by adding `plug_instrumenter` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:plug_instrumenter, "~> 0.1.0"}
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

## Options

In general, you probably want a application level instrumentation callback.
Define it in a module, and configure PlugInstrumenter to use it like so:

```elixir
config :plug_instrumenter,
  callback: {MyApp.PlugInstrumenter, :instrument}
```

More options are available in the documentation.
