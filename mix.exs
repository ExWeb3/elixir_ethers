defmodule Elixirium.MixProject do
  use Mix.Project

  @version "0.0.1-dev"
  @source_url "https://github.com/alisinabh/elixirium"

  def project do
    [
      app: :elixirium,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      name: "Elixirium",
      source_url: @source_url,
      deps: deps(),
      description: "Ethereum/Web3 contract client",
      package: package(),
      docs: docs()
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
      licenses: ["GPL-3.0-or-later"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Alisina Bahadori"],
      files: ["lib", "mix.exs", "README*", "LICENSE*"]
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
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: source_ref,
      groups_for_modules: [
        "Builtin Contracts": [
          ~r/Contract\.\w+$/
        ],
        "Builtin Events": [
          ~r/Contract\.\w+\.Events/
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ethereumex, "~> 0.10.3", optional: true},
      {:ex_abi, "~> 0.5.13"},
      {:ex_doc, "~> 0.28.5"},
      {:jason, "~> 1.4"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
