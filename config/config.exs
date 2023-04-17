import Config

config :ethereumex, url: "https://cloudflare-eth.com/v1/mainnet"

import_config "#{config_env()}.exs"
