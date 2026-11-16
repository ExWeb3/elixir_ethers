# Rules for working with Ethers

Ethers generates an Elixir module from a contract ABI at compile time with `use Ethers.Contract`.
The functions of that module perform no I/O. They return values which `Ethers.call/2`,
`Ethers.send_transaction/2` and `Ethers.get_logs/2` execute. There is no provider, wallet or
contract instance object as in ethers.js or viem.

Read the documentation before writing code that uses Ethers, and do not guess function names:

- The guides ship with the package in `deps/ethers/guides/` and match the installed version. Start
  with `getting-started.md` and `cheatsheet.cheatmd`.
- https://ethers.hexdocs.pm/llms.txt indexes the guides and the API reference of the latest
  release. Every page it lists is also available as Markdown.
