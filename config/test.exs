import Config

config :ethereumex, url: "http://localhost:8545"

config :ethers, ignore_error_consolidation?: true

config :ethers, ccip_req_opts: [plug: {Req.Test, Ethers.CcipReq}, retry: false]
