defmodule Dukascopy.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/theorycraft-trading/dukascopy"
  @homepage_url "https://theorycraft-trading.com"

  def project() do
    [
      app: :dukascopy,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      # elixirc_options: [warnings_as_errors: true],
      dialyzer: [plt_add_apps: [:mix]],
      escript: escript(),
      # Docs
      name: "Dukascopy",
      source_url: @source_url,
      homepage_url: @homepage_url,
      description:
        "Download and stream historical price data for variety of financial instruments (Forex, Commodities and Indices) from Dukascopy Bank SA.",
      package: package(),
      docs: docs()
    ]
  end

  def cli() do
    [preferred_envs: [ci: :test]]
  end

  defp escript() do
    [
      main_module: Dukascopy.CLI,
      app: nil,
      name: "dukascopy",
      include_priv_for: [:lzma]
    ]
  end

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
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},
      {:plug, "~> 1.16", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      ## Test
      {:tzdata, "~> 1.1", only: :test}
    ]
  end

  defp package() do
    [
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"],
      licenses: ["Apache-2.0"],
      links: %{
        "Website" => @homepage_url,
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/v#{@version}/CHANGELOG.md"
      },
      maintainers: ["DarkyZ aka NotAVirus"]
    ]
  end

  defp docs() do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
