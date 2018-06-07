defmodule StubPlug do
  import Plug.Conn

  def init(opts), do: Keyword.put(opts, :extra, true)

  def call(conn, opts) do
    num_called = Map.get(conn.private, :stubplug, 0)

    n = Keyword.get(opts, :num_callbacks, 0)

    conn = put_private(conn, :stubplug, num_called + 1)

    if n > 0 do
      Enum.reduce(0..(n - 1), conn, fn _, conn ->
        register_before_send(conn, callback())
      end)
    else
      conn
    end
  end

  defp callback do
    fn conn ->
      num_after_called = Map.get(conn.private, :stubplug_after, 0)

      conn
      |> put_private(:stubplug_after, num_after_called + 1)
    end
  end
end

defmodule Callback do
  require Logger

  def call(_phase, _times, _opts) do
    Logger.info("passed")
  end

  def now, do: :cool

  def check_now(_, {:cool, :cool}, _), do: Logger.info("passed")
  def check_now(_, times, _), do: raise("expected {:cool, :cool} but got #{inspect(times)}")
end

defmodule PlugInstrumenterTest do
  use ExUnit.Case
  use Plug.Test
  doctest PlugInstrumenter
  import ExUnit.CaptureLog
  require Logger

  test "instrumented plug init method is called with correct opts" do
    {_opts, plug_opts} = PlugInstrumenter.init(plug: StubPlug, opts: [cool: true])

    assert Keyword.get(plug_opts, :cool) == true
    assert Keyword.get(plug_opts, :extra) == true
    refute Keyword.has_key?(plug_opts, :plug)
  end

  test "complains if no :plug option is set" do
    assert_raise(UndefinedFunctionError, fn ->
      PlugInstrumenter.init()
    end)
  end

  test "instrumented plug call method executes" do
    c = conn(:get, "/")
    opts = PlugInstrumenter.init(plug: StubPlug)

    c = PlugInstrumenter.call(c, opts)
    assert Map.has_key?(c.private, :stubplug) == true
    assert c.private[:stubplug] == 1
  end

  test "times instrumented plug execution" do
    c = conn(:get, "/")
    opts = PlugInstrumenter.init(plug: StubPlug)

    c = PlugInstrumenter.call(c, opts)

    assert Map.has_key?(c.private, :stubplug) == true
    assert c.private[:stubplug] == 1
  end

  test "executes and times instrumented plug before_send callback" do
    c = conn(:get, "/")
    opts = PlugInstrumenter.init(plug: StubPlug, opts: [num_callbacks: 1])

    c = PlugInstrumenter.call(c, opts)
    c = execute_before_sends(c)

    assert Map.has_key?(c.private, :stubplug) == true
    assert c.private[:stubplug] == 1
    assert Map.has_key?(c.private, :stubplug_after) == true
    assert c.private[:stubplug_after] == 1
  end

  test "handles multiple before_send callbacks" do
    c = conn(:get, "/")

    opts = PlugInstrumenter.init(plug: StubPlug, opts: [num_callbacks: 3])

    c = PlugInstrumenter.call(c, opts)
    c = execute_before_sends(c)

    assert Map.has_key?(c.private, :stubplug_after) == true
    assert c.private[:stubplug_after] == 3
  end

  test "callback can be set by configuration" do
    c = conn(:get, "/")
    prev = Application.get_env(:plug_instrumenter, :callback)

    Application.put_env(:plug_instrumenter, :callback, {Callback, :call})

    on_exit(fn ->
      if prev == nil do
        Application.delete_env(:plug_instrumenter, :callback)
      else
        Application.put_env(:plug_instrumenter, :callback, prev)
      end
    end)

    opts = PlugInstrumenter.init(plug: StubPlug)
    assert capture_log(fn -> PlugInstrumenter.call(c, opts) end) =~ "passed"
  end

  test "callback can be overriden via options" do
    c = conn(:get, "/")

    opts =
      PlugInstrumenter.init(
        plug: StubPlug,
        callback: {Callback, :call}
      )

    assert capture_log(fn -> PlugInstrumenter.call(c, opts) end) =~ "passed"
  end

  test "callback can be apply'ed" do
    c = conn(:get, "/")
    opts = PlugInstrumenter.init(plug: StubPlug, callback: {Callback, :call})
    assert capture_log(fn -> PlugInstrumenter.call(c, opts) end) =~ "passed"
  end

  test "time function can be apply'ed" do
    c = conn(:get, "/")

    opts =
      PlugInstrumenter.init(
        plug: StubPlug,
        now: {Callback, :now, []},
        callback: {Callback, :check_now}
      )

    assert capture_log(fn -> PlugInstrumenter.call(c, opts) end) =~ "passed"
  end

  defp execute_before_sends(c) do
    Enum.reduce(c.before_send, c, & &1.(&2))
  end
end
