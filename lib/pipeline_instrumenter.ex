defmodule PipelineInstrumenter do
  @moduledoc """
  Instruments a plug pipeline using `PlugInstrumenter`.

  This module can be `use`-d in a module to build an instrumented plug
  pipeline, similar to `Plug.Builder`:

      defmodule MyPipeline do
        use PipelineInstrumenter

        plug Plug.Logger
      end

  Function plugs **do not** work. Each plug
  is wrapped with a `PlugInstrumenter`. `Plug.Builder` options are respected.

  ## Options

  * `:exclude` - A list of plugs to exclude from instrumentation

  Additional options will be passed through to each `PlugInstrumenter` in the
  pipeline that aren't in the `:exclude` list.

  """

  @doc false
  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Plug
      @plug_instrumenter_opts unquote(opts)

      def init(opts) do
        opts
      end

      def call(conn, opts) do
        plug_builder_call(conn, opts)
      end

      defoverridable init: 1, call: 2

      import Plug.Conn
      import PipelineInstrumenter, only: [plug: 1, plug: 2]

      Module.register_attribute(__MODULE__, :instrumented_plugs, accumulate: true)
      @before_compile PipelineInstrumenter
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    builder_opts =
      Keyword.merge(
        Application.get_all_env(:plug_instrumenter),
        Module.get_attribute(env.module, :plug_instrumenter_opts)
      )

    plugs =
      Module.get_attribute(env.module, :instrumented_plugs)
      |> Enum.map(fn {m, plug_opts, guards} = plug ->
        if m in Keyword.get(builder_opts, :exclude, []) do
          plug
        else
          opts = Keyword.merge(builder_opts, plug: m, opts: plug_opts)
          {PlugInstrumenter, opts, guards}
        end
      end)

    {conn, body} = Plug.Builder.compile(env, plugs, builder_opts)

    quote do
      defp plug_builder_call(unquote(conn), _), do: unquote(body)
    end
  end

  defmacro plug(plug, opts \\ []) do
    quote do
      @instrumented_plugs {unquote(plug), unquote(opts), true}
    end
  end
end
