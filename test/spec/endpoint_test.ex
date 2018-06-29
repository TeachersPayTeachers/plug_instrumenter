defmodule Endpoint do
  use PipelineInstrumenter

  plug(Plug.Logger)
end

defmodule CallbackEndpoint do
  use PipelineInstrumenter, callback: {__MODULE__, :callback}

  plug(Plug.Logger)

  def callback(_phase, _times, _opts) do
    :ok
  end
end

defmodule ExcludeCallback do
  use PipelineInstrumenter, exclude: [Plug.Logger]

  plug(Plug.Logger)
end
