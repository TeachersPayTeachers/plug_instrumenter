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

  def name(_mod, _opts) do
    "cool"
  end
end

defmodule ErroringPlug do
  import Plug.Conn

  def init(opts) do
    if Keyword.get(opts, :crash) do
      raise "cool exception"
    end

    opts
  end

  def call(conn, _opts) do
    raise "cool exception"
    conn
  end
end

defmodule OptionPassingPlug do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    conn
    |> put_private(:opts, opts)
  end

  def callback(_phase, _times, opts) do
    Process.put(:plug_instrumenter_opts, opts)
  end

  def name(mod, opts) do
    Process.put(:plug_instrumenter_name, {mod, opts})
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

  test "name option can be an arity 2 function" do
    {opts, _plug_opts} =
      PlugInstrumenter.init(
        plug: StubPlug,
        name: fn _mod, _opts ->
          "cool"
        end
      )

    assert opts.name == "cool"
  end

  test "name option can be an mf" do
    {opts, _plug_opts} = PlugInstrumenter.init(plug: StubPlug, name: {StubPlug, :name})
    assert opts.name == "cool"
  end

  test "plug opts are included in callback opts" do
    {opts, plug_opts} =
      PlugInstrumenter.init(
        plug: OptionPassingPlug,
        opts: [woah: :cool],
        name: {OptionPassingPlug, :name},
        callback: {OptionPassingPlug, :callback}
      )

    c =
      conn(:get, "/")
      |> PlugInstrumenter.call({opts, plug_opts})

    assert [woah: :cool] = c.private[:opts]
    assert opts == Process.get(:plug_instrumenter_opts)
    assert {OptionPassingPlug, name_opts} = Process.get(:plug_instrumenter_name)
    assert name_opts[:plug_opts] == opts[:plug_opts]
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

  test "instrumented plug.init exceptions don't point at instrumenter" do
    try do
      PlugInstrumenter.init(plug: ErroringPlug, opts: [crash: true])
    rescue
      _e ->
        st = System.stacktrace()
        assert {ErroringPlug, :init, 1, _} = hd(st)
    end
  end

  test "instrumented plug.call exceptions don't point at instrumenter" do
    c = conn(:get, "/")
    opts = PlugInstrumenter.init(plug: ErroringPlug)

    try do
      PlugInstrumenter.call(c, opts)
    rescue
      _e ->
        st = System.stacktrace()
        assert {ErroringPlug, :call, 2, _} = hd(st)
    end
  end

  defp execute_before_sends(c) do
    Enum.reduce(c.before_send, c, & &1.(&2))
  end
end
