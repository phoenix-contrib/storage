defmodule StorageEx.Models.BlobServiceMetadata do
  defstruct [:content_type, :disposition, :filename, custom_metadata: %{}]

  @type t :: %__MODULE__{
          content_type: String.t() | nil,
          disposition: String.t() | nil,
          filename: String.t() | nil,
          custom_metadata: map()
        }

  @spec from_blob(StorageEx.Models.Blob.t()) :: t()
  def from_blob(%{__struct__: StorageEx.Models.Blob} = blob) do
    cond do
      forcibly_serve_as_binary?(blob) ->
        %__MODULE__{
          content_type: binary_content_type(),
          disposition: "attachment",
          filename: blob.filename,
          custom_metadata: blob.metadata.custom
        }

      not allowed_inline?(blob) ->
        %__MODULE__{
          content_type: blob.content_type,
          disposition: "attachment",
          filename: blob.filename,
          custom_metadata: blob.metadata.custom
        }

      true ->
        %__MODULE__{
          content_type: blob.content_type,
          custom_metadata: blob.metadata.custom
        }
    end
  end

  # FIXME: Implement actual logic based on your requirements
  defp forcibly_serve_as_binary?(%StorageEx.Models.Blob{}), do: false
  defp allowed_inline?(%StorageEx.Models.Blob{}), do: true
  defp binary_content_type, do: "application/octet-stream"
end
