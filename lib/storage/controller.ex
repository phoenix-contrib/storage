defmodule Storage.Controller do
  @moduledoc """
  Phoenix controller for serving Storage files.

  Add this to your router:

      get "/storage/:key", Storage.Controller, :serve

  Or for more control:

      scope "/storage" do
        get "/:key", Storage.Controller, :serve
        get "/:key/:filename", Storage.Controller, :serve_with_filename
      end

  """

  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Serves a file by its storage key.
  """
  def serve(conn, %{"key" => key}) do
    case Storage.Blob.find_by_key(key) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("File not found")

      blob ->
        serve_blob(conn, blob)
    end
  end

  @doc """
  Serves a file by its storage key with a specific filename in the URL.
  This is useful for SEO and user-friendly URLs.
  """
  def serve_with_filename(conn, %{"key" => key, "filename" => _filename}) do
    # Filename is ignored for security, we use the blob's actual filename
    serve(conn, %{"key" => key})
  end

  @doc """
  Serves a blob with appropriate headers.
  """
  def serve_blob(conn, %Storage.Blob{} = blob) do
    case Storage.get_file(blob) do
      {:ok, data} ->
        conn
        |> put_resp_content_type(blob.content_type)
        |> put_resp_header("content-disposition", content_disposition(blob))
        |> put_resp_header("content-length", to_string(blob.byte_size))
        |> put_resp_header("cache-control", "public, max-age=31536000")
        |> put_resp_header("etag", blob.checksum)
        |> send_resp(200, data)

      {:error, _reason} ->
        conn
        |> put_status(:not_found)
        |> text("File not found")
    end
  end

  @doc """
  Serves a blob as an attachment (forces download).
  """
  def download(conn, %{"key" => key}) do
    case Storage.Blob.find_by_key(key) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("File not found")

      blob ->
        case Storage.get_file(blob) do
          {:ok, data} ->
            conn
            |> put_resp_content_type(blob.content_type)
            |> put_resp_header("content-disposition", "attachment; filename=\"#{blob.filename}\"")
            |> put_resp_header("content-length", to_string(blob.byte_size))
            |> send_resp(200, data)

          {:error, _reason} ->
            conn
            |> put_status(:not_found)
            |> text("File not found")
        end
    end
  end

  # Private functions

  defp content_disposition(%Storage.Blob{} = blob) do
    if inline?(blob) do
      "inline; filename=\"#{blob.filename}\""
    else
      "attachment; filename=\"#{blob.filename}\""
    end
  end

  defp inline?(%Storage.Blob{content_type: content_type}) do
    content_type in [
      "image/jpeg",
      "image/png", 
      "image/gif",
      "image/webp",
      "image/svg+xml",
      "text/plain",
      "application/pdf"
    ]
  end
end