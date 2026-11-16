# Contributing to Elixir Ethers

Thank you for your interest in contributing to Elixir Ethers! We welcome contributions from the community.

## How to Contribute

1. Fork the repository
2. Create a new branch for your feature or bugfix (`git checkout -b your-feature-name`)
3. Make your changes
4. Run the test suite (`mix test`)
5. Ensure code formatting is correct (`mix format`)
6. Commit your changes with a descriptive commit message
7. Push to your fork
8. Open a Pull Request

## Development Setup

1. Ensure you have Elixir installed
2. Clone the repository
3. Install [`solc`](https://docs.soliditylang.org/en/latest/installing-solidity.html) and
   [`jq`](https://jqlang.org/). They compile the test contracts.
4. Install [Foundry](https://getfoundry.sh/) and run `anvil` in a separate terminal
5. Install dependencies with `mix deps.get`
6. Run tests with `mix test`. This compiles the test contracts first
   (`mix run test/test_prepare.exs`), so there is no separate preparation step.

## Documentation

- The README is the landing page on GitHub and Hex.pm. The guides in `guides/` are published on
  HexDocs, with `guides/getting-started.md` as the first page. Build them with `mix docs`.
- `usage-rules.md` and `usage-rules/` are rules for coding agents which use the library. To check
  that the functions they mention exist, build the docs with them included and look for warnings:
  `EXTRA_DOCS="usage-rules.md,usage-rules/*.md" mix docs`
- The "Try it" script of the README and the Livebook tour are executable. Run them with
  `mix run test/doc_examples.exs README.md guides/tour.livemd` (needs network access). A weekly
  workflow does the same.

## Pull Request Guidelines

- Include tests for any new functionality
- Update documentation as needed
- Follow the existing code style
- Keep your changes focused and atomic
- Write clear commit messages

## Questions or Issues?

If you have questions or run into issues, please open a GitHub issue with a clear description of the problem or question.

## License

By contributing to Elixir Ethers, you agree that your contributions will be licensed under its [License](/LICENSE).
