defmodule StorageEx.Operations.Blob.Update do
  @moduledoc """
  Updates the blob with the given attributes inside a transaction.
  This operation is doing several things:
  1. Touching related attachments so are fresh
  2. Update service metadata if :content_type or :metadata changed
  """
  import Ecto.Query, only: [from: 2]
  alias StorageEx.Models.{Blob, Attachment, BlobServiceMetadata}

  def call(repo, %Blob{} = blob, attrs) do
    repo.transaction(fn ->
      changeset = Blob.changeset(blob, attrs)

      with {:ok, blob} <- repo.update(changeset) do
        touch_attachments(repo, blob)

        if update_service_metadata?(blob, changeset.changes) do
          Blob.service(blob).update_metadata(blob)
        end

        {:ok, blob}
      else
        {:error, reason} -> repo.rollback(reason)
      end
    end)
  end

  defp touch_attachments(repo, %Blob{id: blob_id}) do
    from(a in Attachment, where: a.blob_id == ^blob_id)
    |> repo.update_all(set: [updated_at: NaiveDateTime.utc_now()])
  end

  defp update_service_metadata?(%Blob{} = blob, changes) do
    Map.has_key?(changes, :content_type) or Map.has_key?(changes, :metadata)
  end
end
