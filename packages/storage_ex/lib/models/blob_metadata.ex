defmodule StorageEx.Models.BlobMetadata do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          analyzed: boolean(),
          identified: boolean(),
          composed: boolean(),
          custom: map()
        }

  @primary_key false
  embedded_schema do
    field :analyzed, :boolean, default: false
    field :identified, :boolean, default: false
    field :composed, :boolean, default: false
    field :custom, :map, default: %{}
  end

  def changeset(metadata, attrs) do
    cast(metadata, attrs, [:analyzed, :identified, :composed, :custom])
  end

  def put_custom_metadata(%__MODULE__{} = metadata, custom) do
    %{metadata | custom: custom}
  end

  def service_metadata(%__MODULE__{} = md, blob) do
    %{
      content_type: blob.content_type,
      custom_metadata: md.custom || %{}
    }
  end

  @spec service_metadata(StorageEx.Models.Blob.t()) :: map()
  def service_metadata(%{__struct__: StorageEx.Models.Blob} = blob) do
    cond do
      forcibly_serve_as_binary?(blob) ->
        %{
          content_type: binary_content_type(),
          disposition: :attachment,
          filename: blob.filename,
          custom_metadata: blob.metadata.custom
        }

      not allowed_inline?(blob) ->
        %{
          content_type: blob.content_type,
          disposition: :attachment,
          filename: blob.filename,
          custom_metadata: blob.metadata.custom
        }

      true ->
        %{
          content_type: blob.content_type,
          custom_metadata: blob.metadata.custom
        }
    end
  end

  # FIXME: Implement actual logic based on your requirements
  defp forcibly_serve_as_binary?(%{__struct__: _} = StorageEx.Models.Blob), do: false
  defp allowed_inline?(%{__struct__: _} = StorageEx.Models.Blob), do: true
  defp binary_content_type, do: "application/octet-stream"
end
