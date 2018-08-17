defmodule PlugInstrumenter.MixProject do
  use Mix.Project

  @version "0.1.2"

  def project do
    [
      app: :plug_instrumenter,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),

      # docs
      name: "PlugInstrumenter",
      source_url: "https://github.com/TeachersPayTeachers/plug_instrumenter",
      docs: [
        main: "PlugInstrumenter",
        extras: ["README.md"]
      ],

      # tests
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        dialyzer: :test
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  defp package do
    [
      description: "Instrument plugs and plug pipelines",
      licenses: ["MIT"],
      maintainers: [
        "Teachers Pay Teachers",
        "Jeff Martin"
      ],
      links: %{github: "https://github.com/TeachersPayTeachers/plug_instrumenter"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/spec"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:dialyxir, "~> 1.0.0-rc.2", only: [:dev, :test]},
      {:excoveralls, "~> 0.7", only: [:dev, :test]},
      {:ex_doc, "~> 0.18.0", only: [:dev, :test], runtime: false},
      {:inch_ex, "~> 1.0", only: [:dev, :test]},
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
