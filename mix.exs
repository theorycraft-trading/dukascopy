defmodule Dukascopy.MixProject do
  use Mix.Project

  def project() do
    [
      app: :dukascopy,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      preferred_cli_env: [ci: :test],
      aliases: aliases(),
      elixirc_options: [warnings_as_errors: true],
      dialyzer: [plt_add_apps: [:mix]],
      escript: escript()
    ]
  end

  defp escript() do
    [
      main_module: Dukascopy.CLI,
      app: nil,
      name: "dukascopy",
      include_priv_for: [:lzma]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      extra_applications: [:logger],
      mod: {Dukascopy.Application, []}
    ]
  end

  def aliases() do
    [
      tidewave:
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4000) end)'",
      ci: ["format", "credo", "test"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      {:theory_craft, github: "theorycraft-trading/theory_craft"},
      {:req, "~> 0.5"},
      {:lzma, "~> 0.1"},
      {:simple_enum, "~> 0.1"},
      {:nimble_options, "~> 1.1"},
      {:owl, "~> 0.13"},

      ## Dev/Test
      {:tidewave, "~> 0.5", only: :dev},
      {:bandit, "~> 1.0", only: :dev},
      {:plug, "~> 1.16", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      ## Test
      {:tzdata, "~> 1.1", only: :test}
    ]
  end
end
