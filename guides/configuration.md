# Configuration Guide

This guide provides detailed information about configuring Ethers for your Elixir project. We'll cover all available configuration options, their purposes, and best practices for different scenarios.

## Json RPC Configuration

Ethers uses Ethereumex as an Ethereum RPC client by default. A default URL can be set using
the elixir config statements like the example below.

You can use one of the RPC URLs for your chain/wallet of choice or try out one of them from
[chainlist.org](https://chainlist.org). We recommend using a reliable RPC provider (line infura
or quicknodes) for production.

```elixir
# Configure the default JSON-RPC endpoint URL
config :ethereumex, url: "https://..."
```

Note: If your app requires multiple RPC endpoints (e.g. multi-chain) then you need to pass in the
URL for each operation via `:rpc_opts` key. (e.g. `Ethers.call(my_fn, rpc_opts: [url: "https://..."])`

### HTTP options

Ethereumex sends requests with [Finch](https://hexdocs.pm/finch). Its `:http_options` are passed to
`Finch.request/3`, so they take Finch option names, such as `:receive_timeout` (how long to wait for
the response, 15 seconds by default) and `:pool_timeout` (how long to wait for a free connection,
5 seconds by default).

```elixir
config :ethereumex,
  url: "https://...",
  http_options: [receive_timeout: 60_000]
```

HTTPoison/hackney option names such as `:recv_timeout` do not work: Finch versions before 0.22
ignore them, and Finch 0.22 and later raise an `ArgumentError` on every request.

### Per-request options

`:rpc_opts` is passed to the RPC client as is. With Ethereumex it accepts `:url`, `:http_headers`
and, from Ethereumex 0.15, `:http_options`, which are merged over the configured ones:

```elixir
Ethers.call(my_fn, rpc_opts: [url: "https://...", http_options: [receive_timeout: 60_000]])
```

Ethereumex versions before 0.15 ignore `:http_options` in `:rpc_opts` and always use the configured
ones.

## Configuration Options

### RPC Client `:rpc_client`

Specifies the module responsible for making JSON-RPC calls to the Ethereum node. This module must implement
`Ethers.RpcClient.Adapter` behaviour.

#### Example

```elixir
config :ethers, rpc_client: Ethereumex.HttpClient
```

### Keccak Module `:keccak_module`

Module for Keccak-256 hashing operations. Uses `ExKeccak` by default.

#### Example

```elixir
config :ethers, keccak_module: ExKeccak
```

### JSON Module `json_module`

Handles JSON encoding/decoding. Uses `Jason` by default.

#### Example

```elixir
config :ethers, json_module: Jason  # If you prefer using Poison
```

### Secp256k1 Module `:secp256k1_module`

Handles elliptic curve operations for signing and public key operations.

```elixir
config :ethers, secp256k1_module: ExSecp256k1
```

### Default Signer `:default_signer` and `:default_signer_opts`

Specifies the default module for transaction signing by default.
Also use `default_signer_opts` as default signer options if needed (See example).

#### Built-in Siginers

- `Ethers.Signer.Local`: For local private key signing
- `Ethers.Signer.JsonRPC`: For remote signing via RPC

#### Example

```elixir
config :ethers,
  default_signer: Ethers.Signer.Local,
  default_signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
```

### Gas Margins

#### Default Gas Margin `:default_gas_margin`

Safety margin for gas estimation. Precision is 0.01%. Default is 11000 = 110%.

This will increase the estimated gas value so transactions are less likely to run out of gas.

#### Example

```elixir
config :ethers, default_gas_margin: 11000  # 110% gas margin
```

#### Max Fee Per Gas Margin `:default_max_fee_per_gas_margin`

Safety margin for auto-filled max fees. Precision is 0.01%. Default is 12000 = 120%.

It is applied to values derived from the current network price: `max_fee_per_blob_gas` (EIP-4844,
from `eth_blobBaseFee`) and the `max_fee_per_gas` fallback based on `eth_gasPrice`, which is used
when `Ethers.estimate_fees/1` is not available (RPC client without `eth_feeHistory` support, or no
usable fee history). Fees estimated with `Ethers.estimate_fees/1` do not use this margin.

```elixir
config :ethers, default_max_fee_per_gas_margin: 12000  # 120% of current gas price.
```

## Best Practices

1. **Security**:

   - Never commit private keys or sensitive configuration
   - Use environment variables for sensitive values
   - Consider using runtime configuration for flexibility

2. **Gas Management**:

   - Adjust gas margins based on network conditions
   - Use higher margins on networks with more volatility

3. **RPC Endpoints**:

   - Use reliable RPC providers in production
   - Consider fallback RPC endpoints
   - Monitor RPC endpoint performance

4. **Signing**:
   - If possible, Use [ethers_kms](https://hexdocs.pm/ethers_kms) in production for better security
   - Keep private keys secure when using `Ethers.Signer.Local`

## Troubleshooting

### Common Issues

- **RPC Connection Issues**:

```elixir
# Verify your RPC connection
config :ethereumex,
  url: "https://your-ethereum-node.com",
  http_options: [receive_timeout: 60_000]  # Wait longer for slow responses (default 15_000)
```

See [HTTP options](#http-options) for the accepted options.

- **Gas Estimation Failures**:
  Increase gas margin for complex contracts

```elixir
config :ethers, default_gas_margin: 15000  # 150%
```

Or manually provide the gas estimation when sending/signing transactions.
