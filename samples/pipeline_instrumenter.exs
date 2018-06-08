defmodule RawPlug do
  def init(opts), do: opts
  def call(conn, _opts), do: conn
end

defmodule RawBuilder do
  use Plug.Builder

  plug RawPlug
end

defmodule InstrumentedBuilder do
  use PipelineInstrumenter,
    callback: {__MODULE__, :log}

  plug RawPlug

  def log(_, _, _), do: nil
end

use Plug.Test

raw_opts = RawBuilder.init([])
inst_opts = InstrumentedBuilder.init([])
c = conn(:get, "/")
s = 0..1000

Benchee.run(%{
  "raw builder 1000x" => fn ->
    Enum.each(s, fn _ -> RawBuilder.call(c, raw_opts) end)
  end,
  "instrumented builder 1000x" => fn ->
    Enum.each(s, fn _ -> InstrumentedBuilder.call(c, inst_opts) end)
  end
})
