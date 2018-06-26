defmodule PipelineInstrumenter do
  @moduledoc """
  Instruments a plug pipeline using `PlugInstrumenter`.

  # TODO howto do this with phoenix
  """

  @doc false
  defmacro __using__(opts) do
    quote do
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
      |> Enum.map(fn {m, plug_opts, val} = plug ->
        if m in Keyword.get(builder_opts, :exclude, []) do
          plug
        else
          opts = Keyword.merge(builder_opts, plug: m, opts: plug_opts)
          {PlugInstrumenter, opts, val}
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
