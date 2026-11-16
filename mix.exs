defmodule Ethers.MixProject do
  use Mix.Project

  @version "0.8.0"
  @source_url "https://github.com/ExWeb3/elixir_ethers"

  def project do
    [
      app: :ethers,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      name: "Ethers",
      source_url: @source_url,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
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

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        test_prepare: :test
      ]
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => Path.join(@source_url, "/blob/main/CHANGELOG.md")
      },
      maintainers: ["Alisina Bahadori"],
      files: ~w(lib priv guides mix.exs README* LICENSE* CHANGELOG* usage-rules.md usage-rules)
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
      main: "getting-started",
      extras:
        [
          "guides/getting-started.md": [title: "Getting Started"],
          "guides/tour.livemd": [title: "Interactive Tour"],
          "guides/cheatsheet.cheatmd": [title: "Cheatsheet"],
          "guides/contracts.md": [title: "Contracts"],
          "guides/transactions.md": [title: "Transactions"],
          "guides/events.md": [title: "Events"],
          "guides/signing.md": [title: "Signing and Verification"],
          "guides/eip-712.md": [title: "EIP-712 Typed Data"],
          "guides/siwe.md": [title: "Sign-In with Ethereum"],
          "guides/typed-arguments.md": [title: "Typed Arguments"],
          "guides/configuration.md": [title: "Configuration"],
          "guides/upgrading.md": [title: "Upgrading"],
          "CHANGELOG.md": [title: "Changelog"]
        ] ++ extra_docs(),
      groups_for_extras: [
        Introduction: ~w(guides/getting-started.md guides/tour.livemd guides/cheatsheet.cheatmd),
        Guides: ~w(guides/contracts.md guides/transactions.md guides/events.md guides/signing.md
             guides/eip-712.md guides/siwe.md guides/typed-arguments.md guides/configuration.md),
        About: ~w(guides/upgrading.md CHANGELOG.md)
      ],
      source_url: @source_url,
      source_ref: source_ref,
      nest_modules_by_prefix: [
        Ethers.Contracts
      ],
      groups_for_modules: [
        Transactions: [
          "Ethers.Transaction",
          ~r/^Ethers\.Transaction\..*$/
        ],
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
        "Sign-In with Ethereum": [
          "Ethers.Siwe",
          "Ethers.Siwe.Message"
        ],
        "Typed Data": [
          "Ethers.TypedData",
          "Ethers.TypedData.Schema",
          "Ethers.TypedData.Domain",
          "Ethers.TypedData.Field"
        ],
        "Builtin Contract Errors": [
          ~r/^Ethers\.Contracts\..*$/
        ]
      ],
      logo: "assets/exdoc_logo.png",
      before_closing_head_tag: &before_closing_head_tag/1,
      markdown_processor: {ExDoc.Markdown.Earmark, footnotes: true}
    ]
  end

  # Extra pages to run through the docs build, as a comma separated list of globs. Used to
  # check that the functions mentioned in the usage rules exist:
  #
  #     EXTRA_DOCS="usage-rules.md,usage-rules/*.md" mix docs
  defp extra_docs do
    "EXTRA_DOCS"
    |> System.get_env("")
    |> String.split(",", trim: true)
    |> Enum.flat_map(&Path.wildcard/1)
  end

  # Points agents at the generated llms.txt index (see https://llmstxt.org).
  defp before_closing_head_tag(:html),
    do: ~s(<link rel="describedby" type="text/plain" href="llms.txt">)

  defp before_closing_head_tag(_), do: ""

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
      {:ethereumex, "~> 0.10 and >= 0.10.7"},
      {:ex_abi, "~> 0.8.0", optional: System.get_env("SKIP_EX_KECCAK") == "true"},
      {:ex_doc, "~> 0.32", only: :dev, runtime: false},
      {:ex_keccak, "~> 0.7.5"},
      {:ex_rlp, "~> 0.6.0"},
      {:ex_secp256k1, "~> 0.7", optional: true},
      {:excoveralls, "~> 0.10", only: :test},
      {:idna, "~> 7.1 or ~> 8.0"},
      {:jason, "~> 1.4"},
      {:makeup_syntect, "~> 0.1", only: :dev, runtime: false},
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
