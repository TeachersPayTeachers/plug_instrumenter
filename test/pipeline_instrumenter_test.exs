defmodule PipelineInstrumenterTest do
  require Logger

  defmodule NoopPlug do
    import Plug.Conn

    def init(_), do: []
    def call(conn, _opts), do: conn
  end

  defmodule StubPlug do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      conn
      |> put_private(:calls, Map.get(conn.private, :calls, 0) + 1)
    end
  end

  defmodule SetterPlug do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      Enum.reduce(opts, conn, fn {k, v}, conn ->
        assign(conn, k, v)
      end)
    end
  end

  defmodule ErroringPlug do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      raise "cool exception"
      conn
    end
  end

  defmodule ErroringInitPlug do
    import Plug.Conn

    def init(_opts), do: raise("cool exception")

    def call(conn, _opts) do
      conn
    end
  end

  defmodule StubPipeline do
    use PipelineInstrumenter

    plug(NoopPlug)
    plug(SetterPlug, nice: :cool, iknow: :right)
    plug(StubPlug)
  end

  defmodule ExcludingPipeline do
    use PipelineInstrumenter, exclude: [StubPlug]

    plug(SetterPlug, nice: :cool, iknow: :right)
    plug(StubPlug)
  end

  defmodule CallbackPipeline do
    use PipelineInstrumenter, callback: {PipelineInstrumenterTest, :event}

    plug(SetterPlug, nice: :cool, iknow: :right)
    plug(StubPlug)
  end

  defmodule CallbackExcludePipeline do
    use PipelineInstrumenter,
      callback: {PipelineInstrumenterTest, :event},
      exclude: [StubPlug]

    plug(SetterPlug, nice: :cool, iknow: :right)
    plug(StubPlug)
  end

  defmodule CrashingPipeline do
    use PipelineInstrumenter

    plug(ErroringPlug)
  end

  def event(event, _, opts) do
    Logger.info("#{opts.name}: #{event}")

    if Map.get(opts, :log_something_cool) == true do
      Logger.info("aviator sunglasses")
    end
  end

  use ExUnit.Case
  use Plug.Test
  import ExUnit.CaptureLog

  test "executes" do
    c = conn(:get, "/") |> StubPipeline.call([])

    assert %{iknow: :right, nice: :cool} = c.assigns
    assert %{calls: 1} = c.private
  end

  test "executes a settable callback" do
    log =
      capture_log(fn ->
        conn(:get, "/") |> CallbackPipeline.call([])
      end)

    assert log =~ "SetterPlug: pre"
    assert log =~ "StubPlug: pre"
  end

  test "excludes plugs" do
    log =
      capture_log(fn ->
        conn(:get, "/") |> CallbackExcludePipeline.call([])
      end)

    assert log =~ "SetterPlug: pre"
    refute log =~ "StubPlug: pre"
  end

  test "exceptions in inner plug.call points at the inner plug" do
    c = conn(:get, "/")

    try do
      CrashingPipeline.call(c, [])
    rescue
      _e ->
        st = System.stacktrace()
        assert {PipelineInstrumenterTest.ErroringPlug, :call, 2, _} = hd(st)
    end
  end

  test "configuration is respected" do
    log =
      capture_log(fn ->
        conn(:get, "/") |> CallbackPipeline.call([])
      end)

    assert log =~ "aviator sunglasses"
  end
end
