defmodule Storage.Blob do
  @moduledoc """
  Schema for storing file metadata.

  A Blob represents a file stored in the storage system, containing
  metadata like filename, content type, size, and storage location.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "storage_blobs" do
    field :key, :string
    field :filename, :string
    field :content_type, :string
    field :metadata, :map, default: %{}
    field :service_name, :string
    field :byte_size, :integer
    field :checksum, :string

    has_many :attachments, Storage.AttachmentSchema, foreign_key: :blob_id, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(blob, attrs) do
    blob
    |> cast(attrs, [:key, :filename, :content_type, :metadata, :service_name, :byte_size, :checksum])
    |> validate_required([:key, :filename, :content_type, :service_name, :byte_size])
    |> validate_length(:filename, max: 255)
    |> validate_length(:content_type, max: 255)
    |> validate_number(:byte_size, greater_than: 0)
    |> unique_constraint(:key)
  end

  @doc """
  Creates a new blob with the given attributes.
  """
  def create_and_upload!(file_data, attrs) do
    key = generate_key(attrs[:filename])
    service_name = attrs[:service_name] || Storage.Config.default_service()

    blob_attrs = %{
      key: key,
      filename: attrs[:filename],
      content_type: attrs[:content_type] || MIME.from_path(attrs[:filename]),
      service_name: service_name,
      byte_size: byte_size(file_data),
      checksum: generate_checksum(file_data),
      metadata: attrs[:metadata] || %{}
    }

    changeset = changeset(%__MODULE__{}, blob_attrs)

    case Storage.Repo.insert(changeset) do
      {:ok, blob} ->
        case Storage.Services.put_file(service_name, key, file_data) do
          :ok -> blob
          {:error, reason} ->
            Storage.Repo.delete!(blob)
            raise "Failed to upload file: #{inspect(reason)}"
        end

      {:error, changeset} ->
        raise "Failed to create blob: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Finds a blob by its key.
  """
  def find_by_key(key) do
    Storage.Repo.get_by(__MODULE__, key: key)
  end

  @doc """
  Purges blobs that are not attached to any records and older than the given duration.
  """
  def purge_unattached(older_than \\ %{days: 7}) do
    cutoff = DateTime.utc_now() |> DateTime.add(-older_than.days, :day)

    unattached_blobs =
      from b in __MODULE__,
        left_join: a in assoc(b, :attachments),
        where: is_nil(a.id) and b.inserted_at < ^cutoff,
        select: b

    blobs = Storage.Repo.all(unattached_blobs)

    Enum.each(blobs, fn blob ->
      Storage.Services.delete_file(blob.service_name, blob.key)
      Storage.Repo.delete(blob)
    end)

    length(blobs)
  end

  @doc """
  Generates a URL for the blob.
  """
  def url(%__MODULE__{} = blob, opts \\ []) do
    Storage.Services.url(blob.service_name, blob.key, opts)
  end

  @doc """
  Checks if the blob represents an image.
  """
  def image?(%__MODULE__{content_type: content_type}) do
    String.starts_with?(content_type, "image/")
  end

  @doc """
  Checks if the blob represents a video.
  """
  def video?(%__MODULE__{content_type: content_type}) do
    String.starts_with?(content_type, "video/")
  end

  @doc """
  Checks if the blob represents an audio file.
  """
  def audio?(%__MODULE__{content_type: content_type}) do
    String.starts_with?(content_type, "audio/")
  end

  @doc """
  Returns a human-readable representation of the file size.
  """
  def human_size(%__MODULE__{byte_size: size}) do
    human_size(size)
  end

  def human_size(size) when is_integer(size) do
    cond do
      size >= 1_073_741_824 -> "#{Float.round(size / 1_073_741_824, 1)} GB"
      size >= 1_048_576 -> "#{Float.round(size / 1_048_576, 1)} MB"
      size >= 1024 -> "#{Float.round(size / 1024, 1)} KB"
      true -> "#{size} bytes"
    end
  end

  # Private functions

  defp generate_key(filename) do
    ext = Path.extname(filename)
    base = Ecto.UUID.generate()
    "#{base}#{ext}"
  end

  defp generate_checksum(data) when is_binary(data) do
    :crypto.hash(:md5, data) |> Base.encode16(case: :lower)
  end

  defp generate_checksum(%{path: path}) do
    File.read!(path) |> generate_checksum()
  end
end