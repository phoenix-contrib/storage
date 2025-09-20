defmodule Storage.Plug do
  @moduledoc """
  A Plug for serving Storage files directly from your Phoenix application.

  This is useful for local development or when you need to serve files
  through your application server instead of directly from the storage service.

  ## Usage

  Add to your router:

      forward "/storage", Storage.Plug

  Or with options:

      forward "/storage", Storage.Plug, 
        cache_control: "public, max-age=31536000",
        gzip: true

  ## Options

  - `:cache_control` - Cache-Control header value (default: "public, max-age=3600")
  - `:gzip` - Whether to gzip compress responses (default: false)
  - `:etag` - Whether to add ETag header (default: true)

  """

  import Plug.Conn
  
  def init(opts) do
    %{
      cache_control: Keyword.get(opts, :cache_control, "public, max-age=3600"),
      gzip: Keyword.get(opts, :gzip, false),
      etag: Keyword.get(opts, :etag, true)
    }
  end

  def call(%Plug.Conn{path_info: [key]} = conn, opts) do
    serve_file(conn, key, opts)
  end

  def call(%Plug.Conn{path_info: [key, _filename]} = conn, opts) do
    # Serve file by key, ignore filename for security
    serve_file(conn, key, opts)
  end

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "File not found")
  end

  defp serve_file(conn, key, opts) do
    case Storage.Blob.find_by_key(key) do
      nil ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "File not found")

      blob ->
        serve_blob(conn, blob, opts)
    end
  end

  defp serve_blob(conn, blob, opts) do
    # Check if client already has the file cached
    if fresh?(conn, blob) do
      send_resp(conn, 304, "")
    else
      case Storage.get_file(blob) do
        {:ok, data} ->
          conn
          |> put_resp_headers(blob, opts)
          |> maybe_gzip(data, opts)
          |> send_resp(200, data)

        {:error, _reason} ->
          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(404, "File not found")
      end
    end
  end

  defp put_resp_headers(conn, blob, opts) do
    conn
    |> put_resp_content_type(blob.content_type)
    |> put_resp_header("content-length", to_string(blob.byte_size))
    |> put_resp_header("cache-control", opts.cache_control)
    |> put_resp_header("content-disposition", content_disposition(blob))
    |> maybe_put_etag(blob, opts)
  end

  defp maybe_put_etag(conn, blob, %{etag: true}) do
    put_resp_header(conn, "etag", ~s("#{blob.checksum}"))
  end

  defp maybe_put_etag(conn, _blob, _opts), do: conn

  defp maybe_gzip(conn, _data, %{gzip: true}) do
    case get_req_header(conn, "accept-encoding") do
      [encoding] when is_binary(encoding) ->
        if String.contains?(encoding, "gzip") do
          conn
          |> put_resp_header("content-encoding", "gzip")
          |> put_resp_header("vary", "Accept-Encoding")
        else
          conn
        end

      _ ->
        conn
    end
  end

  defp maybe_gzip(conn, _data, _opts), do: conn

  defp content_disposition(blob) do
    if inline?(blob) do
      ~s(inline; filename="#{blob.filename}")
    else
      ~s(attachment; filename="#{blob.filename}")
    end
  end

  defp inline?(blob) do
    blob.content_type in [
      "image/jpeg",
      "image/png",
      "image/gif",
      "image/webp",
      "image/svg+xml",
      "text/plain",
      "application/pdf"
    ]
  end

  defp fresh?(conn, blob) do
    case get_req_header(conn, "if-none-match") do
      [etag] -> etag == ~s("#{blob.checksum}")
      _ -> false
    end
  end
end