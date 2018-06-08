defmodule PlugInstrumenter.MixProject do
  use Mix.Project

  def project do
    [
      app: :plug_instrumenter,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # docs
      name: "PlugInstrumenter",
      source_url: "https://github.com/TeachersPayTeachers/plug_instrumenter",
      docs: [
        main: "PlugInstrumenter",
        extras: ["README.md"]
      ],
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
      {:benchee, "~> 0.11", only: :dev},
      {:dialyxir, "~> 0.4", only: [:dev, :test]},
      {:excoveralls, "~> 0.7", only: [:dev, :test]},
      {:ex_doc, "~> 0.16", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      "ci.install": [
        "local.rebar --force",
        "local.hex --force",
        "deps.get"
      ],
      "ci.run": [
        "coveralls.html",
        "dialyzer",
        "format --check-formatted --check-equivalent",
        "docs"
      ]
    ]
  end
end
