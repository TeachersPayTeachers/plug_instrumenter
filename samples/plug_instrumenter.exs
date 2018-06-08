defmodule RawPlug do
  def init(opts), do: opts
  def call(conn, _opts), do: conn
end

defmodule NoopInstrumenter do
  def log(_, _, _), do: nil
end

use Plug.Test

raw_opts = RawPlug.init([])
inst_opts = PlugInstrumenter.init(plug: RawPlug, callback: {NoopInstrumenter, :log})
c = conn(:get, "/")

Benchee.run(%{
  "raw plug 1000x" => fn ->
    Enum.each(0..1000, fn _ -> RawPlug.call(c, raw_opts) end)
  end,
  "plug instrumenter 1000x" => fn ->
    Enum.each(0..1000, fn _ -> PlugInstrumenter.call(c, inst_opts) end)
  end
})
