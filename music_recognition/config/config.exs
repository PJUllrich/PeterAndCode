import Config

# Use EXLA as the default Nx backend for faster FFT
config :nx, default_backend: EXLA.Backend
