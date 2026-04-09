import Config

# Configure EXLA to use CPU (no GPU required)
if Code.ensure_loaded?(EXLA) do
  config :nx, default_backend: Nx.BinaryBackend
  config :exla, default_client: :host
end
