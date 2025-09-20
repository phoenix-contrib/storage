defmodule Storage.Services.Local do
  @moduledoc """
  Local filesystem storage service.
  """

  @behaviour Storage.Services

  @impl Storage.Services
  def put_file(key, data, config) do
    root = Keyword.get(config, :root, "/tmp/storage")
    path = Path.join(root, key)

    with :ok <- ensure_directory(path),
         :ok <- write_file(path, data) do
      :ok
    end
  end

  @impl Storage.Services
  def get_file(key, config) do
    root = Keyword.get(config, :root, "/tmp/storage")
    path = Path.join(root, key)

    File.read(path)
  end

  @impl Storage.Services
  def delete_file(key, config) do
    root = Keyword.get(config, :root, "/tmp/storage")
    path = Path.join(root, key)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok  # File doesn't exist, consider it deleted
      error -> error
    end
  end

  @impl Storage.Services
  def url(key, config, opts \\ []) do
    # For local storage, we need a way to serve files
    # This could be through a Phoenix route or controller
    base_url = Keyword.get(opts, :base_url, "/storage")
    "#{base_url}/#{key}"
  end

  @impl Storage.Services
  def signed_url(key, config, opts \\ []) do
    # Local storage doesn't need signed URLs, just return the regular URL
    {:ok, url(key, config, opts)}
  end

  # Private functions

  defp ensure_directory(file_path) do
    file_path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  defp write_file(path, data) when is_binary(data) do
    File.write(path, data)
  end

  defp write_file(path, %{path: source_path}) do
    File.copy(source_path, path)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end
end