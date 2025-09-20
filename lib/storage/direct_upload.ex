defmodule Storage.DirectUpload do
  @moduledoc """
  Handles direct uploads to storage services.

  Direct uploads allow clients to upload files directly to the storage service
  (like S3) without going through your Phoenix server, improving performance
  and reducing server load.

  ## Usage

      # Generate a signed URL for direct upload
      {:ok, upload_data} = Storage.DirectUpload.signed_url(
        filename: "document.pdf",
        content_type: "application/pdf",
        byte_size: 1024000
      )

      # The client uploads directly using the returned data
      # Then creates the blob record:
      {:ok, blob} = Storage.DirectUpload.create_blob_after_direct_upload(upload_data)

  """

  alias Storage.{Blob, Config}

  @doc """
  Generates a signed URL and metadata for direct upload.

  ## Options

  - `:filename` - Original filename (required)
  - `:content_type` - MIME type (inferred from filename if not provided)
  - `:byte_size` - File size in bytes (required for some services)
  - `:service_name` - Storage service to use (defaults to configured default)
  - `:expires_in` - URL expiration time in seconds (default: 3600)
  - `:max_file_size` - Maximum allowed file size (default: 100MB)
  - `:metadata` - Additional metadata to store with the blob

  ## Returns

  Returns `{:ok, upload_data}` where `upload_data` contains:

  - `:url` - The upload URL
  - `:fields` - Form fields required for the upload
  - `:key` - The storage key that will be used
  - `:blob_attributes` - Attributes to create the blob after upload

  """
  def signed_url(opts \\ []) do
    filename = Keyword.get(opts, :filename) || 
      raise ArgumentError, "filename is required"

    content_type = Keyword.get(opts, :content_type) || 
      MIME.from_path(filename)

    byte_size = Keyword.get(opts, :byte_size) ||
      raise ArgumentError, "byte_size is required for direct uploads"

    service_name = Keyword.get(opts, :service_name) || Config.default_service()
    expires_in = Keyword.get(opts, :expires_in, 3600)
    max_file_size = Keyword.get(opts, :max_file_size, 100_000_000)
    metadata = Keyword.get(opts, :metadata, %{})

    key = generate_key(filename)
    checksum = generate_placeholder_checksum()

    blob_attributes = %{
      key: key,
      filename: filename,
      content_type: content_type,
      service_name: service_name,
      byte_size: byte_size,
      checksum: checksum,
      metadata: metadata
    }

    case generate_signed_url(service_name, key, opts) do
      {:ok, url_data} ->
        upload_data = Map.merge(url_data, %{
          key: key,
          blob_attributes: blob_attributes
        })

        {:ok, upload_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a blob record after a successful direct upload.

  This should be called after the client has successfully uploaded the file
  using the signed URL data.
  """
  def create_blob_after_direct_upload(upload_data) do
    blob_attrs = Map.get(upload_data, :blob_attributes)
    
    changeset = Blob.changeset(%Blob{}, blob_attrs)
    Storage.Repo.insert(changeset)
  end

  @doc """
  Verifies that a direct upload was successful by checking if the file exists.
  """
  def verify_upload(key, service_name \\ nil) do
    service_name = service_name || Config.default_service()
    
    case Storage.Services.get_file(service_name, key) do
      {:ok, _data} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a complete direct upload flow with verification.

  ## Example

      {:ok, upload_data} = Storage.DirectUpload.prepare_direct_upload(
        filename: "image.jpg",
        content_type: "image/jpeg",
        byte_size: 512000
      )

      # Client uploads file...

      {:ok, blob} = Storage.DirectUpload.finalize_direct_upload(upload_data.key)

  """
  def prepare_direct_upload(opts) do
    signed_url(opts)
  end

  def finalize_direct_upload(key, service_name \\ nil) do
    service_name = service_name || Config.default_service()

    case verify_upload(key, service_name) do
      :ok ->
        # Find the blob by key (it should have been created during prepare phase)
        case Blob.find_by_key(key) do
          nil -> {:error, :blob_not_found}
          blob -> {:ok, blob}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp generate_signed_url(service_name, key, opts) do
    {module, config} = Config.service_config(service_name)
    
    case module do
      Storage.Services.S3 ->
        s3_signed_upload_url(module, key, config, opts)

      Storage.Services.Local ->
        # Local storage doesn't support direct uploads in the traditional sense
        # Return a regular upload URL that goes through your Phoenix app
        {:ok, %{
          url: "/storage/direct_upload",
          fields: %{key: key},
          method: "POST"
        }}

      _ ->
        {:error, :unsupported_service}
    end
  end

  defp s3_signed_upload_url(module, key, config, opts) do
    expires_in = Keyword.get(opts, :expires_in, 3600)
    content_type = Keyword.get(opts, :content_type)
    max_file_size = Keyword.get(opts, :max_file_size, 100_000_000)

    s3_opts = [
      expires_in: expires_in,
      content_type: content_type,
      max_file_size: max_file_size
    ]

    case apply(module, :signed_upload_url, [key, config, s3_opts]) do
      {:ok, presigned_data} ->
        {:ok, %{
          url: presigned_data.url,
          fields: presigned_data.fields,
          method: "POST"
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_key(filename) do
    ext = Path.extname(filename)
    base = Ecto.UUID.generate()
    "#{base}#{ext}"
  end

  defp generate_placeholder_checksum do
    # Generate a placeholder checksum that will be updated after upload
    :crypto.hash(:md5, "placeholder") |> Base.encode16(case: :lower)
  end
end