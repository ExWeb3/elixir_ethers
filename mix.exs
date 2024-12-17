defmodule Ethers.MixProject do
  use Mix.Project

  @version "0.5.5"
  @source_url "https://github.com/ExWeb3/elixir_ethers"

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
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        test_prepare: :test
      ],
      description:
        "A comprehensive Web3 library for interacting with smart contracts on Ethereum using Elixir.",
      package: package(),
      docs: docs(),
      aliases: aliases(),
      dialyzer: dialyzer()
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
      files: ["lib", "priv", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"]
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
      extras: [
        "README.md": [title: "Introduction"],
        "CHANGELOG.md": [title: "Changelog"],
        "guides/typed-arguments.md": [title: "Typed Arguments"]
      ],
      source_url: @source_url,
      source_ref: source_ref,
      nest_modules_by_prefix: [
        Ethers.Contracts
      ],
      groups_for_modules: [
        "Builtin Contracts": [
          ~r/^Ethers\.Contracts\.(?:(?!EventFilters$|Errors\.).)*$/
        ],
        "Builtin EventFilters": [
          ~r/^Ethers\.Contracts\.[A-Za-z0-9.]+\.EventFilters$/
        ],
        Signer: [
          ~r/^Ethers\.Signer\.[A-Za-z0-9.]+$/,
          ~r/^Ethers\.Signer$/
        ],
        "Builtin Contract Errors": [
          ~r/^Ethers\.Contracts\..*$/
        ]
      ],
      logo: "assets/exdoc_logo.png",
      markdown_processor: {ExDoc.Markdown.Earmark, footnotes: true}
    ]
  end

  def dialyzer do
    [flags: [:error_handling, :extra_return, :underspecs, :unknown, :unmatched_returns]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ethereumex, "~> 0.10.6"},
      {:ex_abi, "~> 0.8.0", optional: System.get_env("SKIP_EX_KECCAK") == "true"},
      {:ex_doc, "~> 0.32", only: :dev, runtime: false},
      {:ex_keccak, "~> 0.7.5"},
      {:ex_rlp, "~> 0.6.0"},
      {:ex_secp256k1, "~> 0.7.2", optional: true},
      {:excoveralls, "~> 0.10", only: :test},
      {:idna, "~> 6.1"},
      {:jason, "~> 1.4"},
      {:plug, ">= 1.0.0", only: :test},
      {:req, "~> 0.5"}
    ]
  end

  def aliases do
    [
      test_prepare: ["run test/test_prepare.exs"],
      test: ["test_prepare", "test"]
    ]
  end
end
