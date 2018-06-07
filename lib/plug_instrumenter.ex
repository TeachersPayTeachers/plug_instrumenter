defmodule PlugInstrumenter do
  @moduledoc """
  Reports plug timing to a configurable callback function.

  Wraps plugs, adding instrumentation. Use it in your plug pipeline like this:

  ```elixir
  plug PlugInstrumenter, plug: MyPlug
  ```

  Pass options to the plug like this:

  ```elixir
  plug PlugInstrumenter, plug: MyPlug, opts: [my_opt: :cool]
  ```

  Metrics are passed to a configured callback, and a configurable name where
  the default is based on the module's name. for the above example,
  `myplug_pre` would be logged.

  If your plug registers a before_send callback, that will be timed as well,
  and given a separate name. For the above example, `myplug_post` would be
  logged.

  Initialization can also be timed. Under the default configuration, the name
  `myplug_init` would be logged.

  Here is an invocation with the default values specified:

  ```elixir
  plug PlugInstrumenter, plug: MyPlug, opts: [my_opt: :cool],
    name: :cool_name,
    callback: fn phase, {started_at, finished_at}, opts ->
      IO.puts("\#{opts.name}_\#{phase}: \#{finished_at - started_at}")
    end,
    now: {:erlang, :monotonic_time, [:microsecond]}
  ```

  """

  import Plug.Conn
  require Logger

  @type phase_t :: :init | :pre | :post

  @type callback_t :: {module, atom}

  @type opts_t :: %{
          plug: module,
          name: String.t(),
          callback: callback_t,
          now: {module, atom, [any]} | {(... -> any), [any]}
        }

  @type plug_opts_t :: {opts_t, any}

  @assign :__plug_timings

  @spec init(Keyword.t()) :: plug_opts_t() | no_return
  def init(opts) when is_list(opts) do
    mod = Keyword.fetch!(opts, :plug)
    opts_set? = Keyword.has_key?(opts, :opts)
    {plug_opts, instrumenter_opts} = Keyword.pop(opts, :opts)

    plug_opts = if opts_set?, do: plug_opts, else: []

    opts =
      Application.get_all_env(:plug_instrumenter)
      |> Keyword.merge(instrumenter_opts)
      |> Map.new()
      |> set_instrumenter_opts()

    plug_opts =
      if init_callback?(instrumenter_opts) do
        started_at = now(opts.now)
        plug_opts = mod.init(plug_opts)
        finished_at = now(opts.now)
        callback(opts.callback, [:init, {started_at, finished_at}, opts])
        plug_opts
      else
        plug_opts = mod.init(plug_opts)
      end

    {opts, plug_opts}
  end

  def init(_opts) do
    raise "#{__MODULE__} must be initialized with a :plug option in a keyword list"
  end

  @spec call(Plug.Conn.t(), plug_opts_t()) :: Plug.Conn.t()
  def call(conn, {opts, plug_opts}) do
    mod = opts.plug
    before_len = length(conn.before_send)

    started_at = now(opts.now)
    conn = mod.call(conn, plug_opts)
    callback(opts.callback, [:pre, {started_at, now(opts.now)}, opts])

    after_len = length(conn.before_send)
    diff = after_len - before_len

    if diff > 0 do
      %{before_send: before_send} = conn

      before_send = List.insert_at(before_send, diff, after_hook(opts))

      %{conn | before_send: [before_hook(opts) | before_send]}
    else
      conn
    end
  end

  defp init_callback?(kwopts) do
    init_mode = Keyword.get(kwopts, :init_mode)

    case Keyword.get(kwopts, :callback) do
      nil ->
        false

      {m, f} ->
        case init_mode do
          :runtime -> true
          :compile -> Module.defines?(m, {f, 3})
          nil -> false
        end
    end
  end

  defp callback({m, f}, a), do: apply(m, f, a)
  defp callback(nil, a), do: apply(&default_callback/3, a)

  defp now({m, f, a}), do: apply(m, f, a)

  defp set_instrumenter_opts(%{plug: mod} = opts) do
    opts
    |> Map.put_new_lazy(:name, fn -> default_name(mod) end)
    |> Map.put_new(:callback, nil)
    |> Map.put_new(:now, {:erlang, :monotonic_time, [:microsecond]})
  end

  defp default_name(mod) do
    mod
    |> Module.split()
    |> Enum.map(&Macro.underscore(&1))
    |> Enum.join("_")
  end

  defp default_callback(phase, {start, finish}, opts) do
    name = Enum.join([opts.name, phase], "_")
    Logger.debug("#{name}: #{finish - start}")
  end

  defp before_hook(opts) do
    fn conn ->
      timings = conn.private[@assign] || %{}
      timings = Map.put(timings, opts.name, now(opts.now))

      put_private(conn, @assign, timings)
    end
  end

  defp after_hook(opts) do
    fn conn ->
      started_at = Map.fetch!(conn.private[@assign], opts.name)
      callback(opts.callback, [:post, {started_at, now(opts.now)}, opts])
      conn
    end
  end
end
