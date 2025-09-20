defmodule Storage.Uploader do
  @moduledoc """
  Handles file uploads and creates blobs.
  """

  alias Storage.Blob

  @doc """
  Uploads a file and creates a blob record.

  ## Options

  - `:filename` - The original filename (required)
  - `:content_type` - MIME type of the file (inferred from filename if not provided)
  - `:service_name` - Storage service to use (defaults to configured default)
  - `:metadata` - Additional metadata to store with the blob

  ## Examples

      # Upload from file path
      Storage.Uploader.put("/path/to/file.jpg", filename: "avatar.jpg")

      # Upload binary data
      Storage.Uploader.put(file_binary, 
        filename: "document.pdf", 
        content_type: "application/pdf"
      )

      # Upload with metadata
      Storage.Uploader.put(file_data, 
        filename: "image.jpg",
        metadata: %{alt_text: "Profile picture", user_id: 123}
      )

  """
  def put(file_data, opts \\ []) do
    filename = Keyword.get(opts, :filename) || 
      raise ArgumentError, "filename is required"

    content_type = Keyword.get(opts, :content_type) || 
      MIME.from_path(filename)

    service_name = Keyword.get(opts, :service_name) || 
      Storage.Config.default_service()

    metadata = Keyword.get(opts, :metadata, %{})

    # Normalize file data
    normalized_data = normalize_file_data(file_data)

    attrs = %{
      filename: filename,
      content_type: content_type,
      service_name: service_name,
      metadata: metadata
    }

    try do
      blob = Blob.create_and_upload!(normalized_data, attrs)
      {:ok, blob}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Same as `put/2` but raises on error.
  """
  def put!(file_data, opts \\ []) do
    case put(file_data, opts) do
      {:ok, blob} -> blob
      {:error, error} -> raise error
    end
  end

  # Private functions

  defp normalize_file_data(path) when is_binary(path) do
    if File.exists?(path) do
      File.read!(path)
    else
      path  # Assume it's binary data
    end
  end

  defp normalize_file_data(%{path: path}) do
    File.read!(path)
  end

  defp normalize_file_data(data) when is_binary(data) do
    data
  end

  defp normalize_file_data(%Plug.Upload{path: path}) do
    File.read!(path)
  end
end