defmodule App.EncryptedBinary do
  use Cloak.Ecto.Binary, vault: App.Vault
end
