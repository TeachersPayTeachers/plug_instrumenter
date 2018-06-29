defmodule PlugInstrumenter do
  @moduledoc """
  Reports plug timing to a configurable callback function.

  Wraps plugs, adding instrumentation. Use it in your plug pipeline like this:

      plug PlugInstrumenter, plug: MyPlug

  Pass options to the plug like this:

      plug PlugInstrumenter, plug: MyPlug, opts: [my_opt: :cool]

  Metrics are passed to a configured callback, and a configurable name where
  the default is based on the module's name. There are three phases that can be
  instrumented:

  * `:pre` - when the `call/2` function is executed.
  * `:post` - when the `before_send` callbacks are executed.
  * `:init` - when the `init/1` function is executed.

  ## Options

  Options can be set in your configuration under the `:plug_instrumenter`
  namespace. They will be overridden by options passed to the `plug` macro.

  * `:plug` - The plug to instrument
  * `:now` - a module/function tuple pointing to an mfa that returns the
    current time. Default is `:erlang.monotonic_time(:microsecond)`.
  * `:callback` - The instrumentation callback, which should have a 3-arity
    function. The default callback calls `Logger.debug`. The arguments passed
    to the function are as follows:
    * `phase` - one of:
      * `:init` - executed after the `init/1` has completed
      * `:pre` - executed after the `call/2` method has completed
      * `:post` - executed after before_send callbacks have completed
    * `{start, finish}` - the start and finish time, as reported by `:now`
    * `opts` the PlugInstrumenter options represented as a map.
  * `:name` - a string or 2-arity function that returns the metric name as a
    string. If a function is used, it will be called during the plug's init
    phase with the following arguments:
      * `module` - The name of the plug module
      * `opts` - The options passed to the plug instrumenter. The instrumented
        plug's options are included via the key `:plug_opts`.

  """

  import Plug.Conn
  require Logger

  @type phase_t :: :init | :pre | :post

  @type callback_t :: {module, atom}

  @type plug_opts_t :: {opts_t, any}

  @type opts_t :: %{
          required(:plug) => module,
          required(:name) => String.t(),
          optional(:callback) => callback_t(),
          required(:now) => {module, atom, [any]},
          required(:plug_opts) => any,
          optional(atom) => any
        }

  @assign :__plug_timings

  @doc false
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
      |> Map.put(:plug_opts, plug_opts)
      |> set_instrumenter_opts()

    plug_opts =
      if init_callback?(instrumenter_opts) do
        started_at = now(opts)
        plug_opts = mod.init(plug_opts)
        finished_at = now(opts)
        callback(opts, [:init, {started_at, finished_at}, opts])
        plug_opts
      else
        mod.init(plug_opts)
      end

    {opts, plug_opts}
  end

  def init(_opts) do
    raise "#{__MODULE__} must be initialized with a :plug option in a keyword list"
  end

  @doc false
  @spec call(Plug.Conn.t(), plug_opts_t()) :: Plug.Conn.t()
  def call(conn, {opts, plug_opts}) do
    mod = opts.plug
    before_len = length(conn.before_send)

    started_at = now(opts)
    conn = mod.call(conn, plug_opts)
    callback(opts, [:pre, {started_at, now(opts)}, opts])

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

  defp callback(%{callback: {m, f}}, a), do: apply(m, f, a)
  defp callback(_, a), do: apply(&default_callback/3, a)

  defp now(%{now: {m, f, a}}), do: apply(m, f, a)

  defp set_instrumenter_opts(%{plug: mod} = opts) do
    set_opts =
      opts
      |> Map.put_new_lazy(:name, fn -> default_name(mod) end)
      |> Map.put_new(:now, {:erlang, :monotonic_time, [:microsecond]})

    name =
      case Map.fetch!(set_opts, :name) do
        fun when is_function(fun, 2) -> fun.(mod, set_opts)
        {m, f} -> apply(m, f, [mod, set_opts])
        name -> name
      end

    Map.put(set_opts, :name, name)
  end

  defp default_name(mod) when is_atom(mod) do
    mod
    |> Atom.to_string()
    |> case do
      "Elixir." <> name -> String.split(name, ".") |> List.last()
      s -> s
    end
  end

  defp default_name(mod), do: to_string(mod)

  defp default_callback(phase, {start, finish}, opts) do
    name = Enum.join([opts.name, phase], "_")
    Logger.debug("#{name}: #{finish - start}")
  end

  defp before_hook(opts) do
    fn conn ->
      timings = conn.private[@assign] || %{}
      timings = Map.put(timings, opts.name, now(opts))

      put_private(conn, @assign, timings)
    end
  end

  defp after_hook(opts) do
    fn conn ->
      started_at = Map.fetch!(conn.private[@assign], opts.name)
      callback(opts, [:post, {started_at, now(opts)}, opts])
      conn
    end
  end
end
