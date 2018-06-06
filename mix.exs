defmodule PlugInstrumenter.MixProject do
  use Mix.Project

  def project do
    [
      app: :plug_instrumenter,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:plug],
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 0.4", only: [:dev, :test]},
      {:excoveralls, "~> 0.7", only: [:dev, :test]},
      {:plug, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      ci: ["coveralls.html", "dialyzer", "format --check-formatted --check-equivalent"]
    ]
  end
end
