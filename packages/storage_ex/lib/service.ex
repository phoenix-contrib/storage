defmodule StorageEx.Service do
  @moduledoc """
  Behaviour for storage services (local, S3, GCS, Azure, etc).
  """
  alias StorageEx.Models.BlobServiceMetadata

  @callback new(config :: map()) :: struct() | {:error, term()}
  @callback update_metadata(key :: String.t(), metadata :: BlobServiceMetadata.t()) :: :ok | {:error, term()}
  @optional_callbacks update_metadata: 2

  @type t :: module()

  defmacro __using__(_opts) do
    quote do
      @behaviour StorageEx.Service

      @impl true
      def update_metadata(_key, _metadata), do: :ok
      defoverridable update_metadata: 2
    end
  end
end
