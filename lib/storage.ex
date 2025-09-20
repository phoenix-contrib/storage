defmodule Storage do
  @moduledoc """
  ActiveStorage-like file storage for Phoenix.

  Storage provides a unified interface for handling file uploads in Phoenix applications,
  supporting multiple storage backends and following the design principles of Rails ActiveStorage.

  ## Features

  - Multiple storage backends (local filesystem, S3, etc.)
  - Direct uploads with signed URLs
  - Image processing and variants
  - Ecto schema integration
  - Phoenix LiveView support
  - Configurable storage services

  ## Configuration

  Add to your `config.exs`:

      config :storage,
        default_service: :local,
        services: %{
          local: {Storage.Services.Local, root: "/tmp/storage"},
          s3: {Storage.Services.S3, bucket: "my-bucket", region: "us-east-1"}
        }

  ## Usage

  ### In your schema

      defmodule MyApp.User do
        use Ecto.Schema
        use Storage.Attachment

        schema "users" do
          field :name, :string
          has_one_attached :avatar
          has_many_attached :documents
        end
      end

  ### In your LiveView

      def handle_event("save", %{"user" => user_params}, socket) do
        uploaded_files =
          consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
            {:ok, Storage.put_file(path, filename: entry.client_name)}
          end)

        # Use uploaded_files...
      end
  """

  alias Storage.{Blob, Attachment}

  @doc """
  Stores a file and returns a Blob struct.

  ## Examples

      Storage.put_file("/path/to/file.jpg", filename: "avatar.jpg")
      Storage.put_file(file_binary, filename: "document.pdf", content_type: "application/pdf")

  """
  def put_file(file, opts \\ []) do
    Storage.Uploader.put(file, opts)
  end

  @doc """
  Retrieves a file from storage.

  ## Examples

      Storage.get_file(blob)
      Storage.get_file(blob.key)

  """
  def get_file(%Blob{} = blob) do
    Storage.Services.get_file(blob.service_name, blob.key)
  end

  def get_file(key) when is_binary(key) do
    # For now, assume default service
    service_name = Storage.Config.default_service()
    Storage.Services.get_file(service_name, key)
  end

  @doc """
  Deletes a file from storage.

  ## Examples

      Storage.delete_file(blob)
      Storage.delete_file(blob.key)

  """
  def delete_file(%Blob{} = blob) do
    Storage.Services.delete_file(blob.service_name, blob.key)
  end

  def delete_file(key) when is_binary(key) do
    service_name = Storage.Config.default_service()
    Storage.Services.delete_file(service_name, key)
  end

  @doc """
  Generates a signed URL for direct uploads.

  ## Examples

      Storage.signed_url_for_direct_upload(filename: "image.jpg", content_type: "image/jpeg")

  """
  def signed_url_for_direct_upload(opts \\ []) do
    Storage.DirectUpload.signed_url(opts)
  end

  @doc """
  Purges orphaned blobs that are not attached to any records.
  """
  def purge_unattached(older_than \\ %{days: 7}) do
    Storage.Blob.purge_unattached(older_than)
  end
end