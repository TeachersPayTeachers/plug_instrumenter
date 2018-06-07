defmodule PipelineInstrumenter do
  @moduledoc """

  """

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour Plug
      @plug_builder_opts unquote(opts)

      def init(opts) do
        opts
      end

      def call(conn, opts) do
        plug_builder_call(conn, opts)
      end

      defoverridable init: 1, call: 2

      import Plug.Conn
      import Plug.Builder, only: [plug: 1, plug: 2]

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile PipelineInstrumenter
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    builder_opts = Module.get_attribute(env.module, :plug_builder_opts)

    plugs =
      Module.get_attribute(env.module, :plugs)
      |> Enum.map(fn {m, plug_opts, val} = plug ->
        if m in Keyword.get(builder_opts, :exclude, []) do
          plug
        else
          opts = [plug: m, opts: plug_opts]
          callback = Keyword.get(builder_opts, :callback)

          opts =
            if callback do
              [{:callback, callback} | opts]
            else
              opts
            end

          {PlugInstrumenter, opts, val}
        end
      end)

    # IO.inspect(plugs, label: :plugs)
    {conn, body} = Plug.Builder.compile(env, plugs, builder_opts)

    quote do
      defp plug_builder_call(unquote(conn), _), do: unquote(body)
    end
  end
end
