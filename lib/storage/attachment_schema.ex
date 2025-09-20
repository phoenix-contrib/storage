defmodule Storage.AttachmentSchema do
  @moduledoc """
  Schema for linking records to blobs.

  An Attachment represents the relationship between a record (like User)
  and a Blob (the actual file). This allows for polymorphic associations
  where any record can have attachments.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "storage_attachments" do
    field :name, :string
    field :record_type, :string
    field :record_id, :binary_id

    belongs_to :blob, Storage.Blob, foreign_key: :blob_id, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:name, :record_type, :record_id, :blob_id])
    |> validate_required([:name, :record_type, :record_id, :blob_id])
    |> validate_length(:name, max: 255)
    |> validate_length(:record_type, max: 255)
    |> foreign_key_constraint(:blob_id)
    |> unique_constraint([:record_type, :record_id, :name, :blob_id])
  end

  @doc """
  Creates an attachment for the given record and blob.
  """
  def create!(record, name, blob) do
    attrs = %{
      name: to_string(name),
      record_type: record.__struct__ |> Module.split() |> List.last(),
      record_id: record.id,
      blob_id: blob.id
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Storage.Repo.insert!()
  end

  @doc """
  Finds attachments for a given record and name.
  """
  def for_record(record, name) do
    record_type = record.__struct__ |> Module.split() |> List.last()

    from a in __MODULE__,
      where: a.record_type == ^record_type and a.record_id == ^record.id and a.name == ^to_string(name),
      preload: [:blob]
  end

  @doc """
  Finds a single attachment for a given record and name.
  """
  def find_for_record(record, name) do
    for_record(record, name) |> Storage.Repo.one()
  end

  @doc """
  Finds all attachments for a given record and name.
  """
  def all_for_record(record, name) do
    for_record(record, name) |> Storage.Repo.all()
  end

  @doc """
  Purges an attachment and its associated blob if no other attachments reference it.
  """
  def purge!(%__MODULE__{} = attachment) do
    blob = Storage.Repo.preload(attachment, :blob).blob
    Storage.Repo.delete!(attachment)

    # Check if this blob has other attachments
    other_attachments =
      from a in __MODULE__,
        where: a.blob_id == ^blob.id,
        select: count(a.id)

    case Storage.Repo.one(other_attachments) do
      0 ->
        # No other attachments, safe to delete the blob
        Storage.Services.delete_file(blob.service_name, blob.key)
        Storage.Repo.delete!(blob)

      _ ->
        # Other attachments exist, keep the blob
        :ok
    end
  end

  @doc """
  Detaches an attachment without deleting the underlying blob.
  """
  def detach!(%__MODULE__{} = attachment) do
    Storage.Repo.delete!(attachment)
  end
end