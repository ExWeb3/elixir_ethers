import Config

config :ethereumex, url: "https://eth.llamarpc.com"

import_config "#{config_env()}.exs"
