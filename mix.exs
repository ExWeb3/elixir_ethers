defmodule Ethers.MixProject do
  use Mix.Project

  @version "0.0.2"
  @source_url "https://github.com/alisinabh/elixir_ethers"

  def project do
    [
      app: :ethers,
      version: @version,
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      name: "Ethers",
      source_url: @source_url,
      deps: deps(),
      description: "Ethereum/Web3 client based on ethers.js",
      package: package(),
      docs: docs(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ethereumex]
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Alisina Bahadori"],
      files: ["lib", "priv", "mix.exs", "README*", "LICENSE*"]
    ]
  end

  defp docs do
    source_ref =
      if String.ends_with?(@version, "-dev") do
        "main"
      else
        "v#{@version}"
      end

    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: source_ref,
      groups_for_modules: [
        "Builtin Contracts": [
          ~r/Contracts\.\w+$/
        ],
        "Builtin EventFilters": [
          ~r/Contracts\.\w+\.EventFilters/
        ]
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:ethereumex, "~> 0.10.3"},
      {:ex_abi, "~> 0.6.0"},
      {:ex_doc, "~> 0.29.4", only: :dev, runtime: false},
      {:idna, "~> 6.1"},
      {:jason, "~> 1.4"}
    ]
  end

  def aliases do
    [
      test_prepare: ["run test/test_prepare.exs"],
      test: ["test_prepare", "test"]
    ]
  end
end
