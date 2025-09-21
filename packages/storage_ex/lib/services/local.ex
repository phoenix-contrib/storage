defmodule StorageEx.Services.Local do
  @moduledoc """
  Local storage service.

  Files are stored on disk under the configured root path.
  """
  use StorageEx.Service

  defstruct [:root]

  @type t :: %__MODULE__{
          root: String.t()
        }

  @impl true
  def new(config) when is_map(config) do
    root = Map.get(config, :root, default_root())

    case File.mkdir_p(root) do
      :ok ->
        %__MODULE__{root: root}
      {:error, reason} ->
        {:error, "Failed to create storage directory #{root}: #{inspect(reason)}"}
    end
  end

  @doc """
  Stores a file (binary data) at the given key.
  """
  def put(%__MODULE__{root: root}, key, binary) when is_binary(binary) do
    path = path_for(root, key)

    case File.mkdir_p(Path.dirname(path)) do
      :ok ->
        case File.write(path, binary) do
          :ok -> {:ok, key}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Reads a file by key.
  """
  def get(%__MODULE__{root: root}, key) do
    path = path_for(root, key)
    File.read(path)
  end

  @doc """
  Deletes a file by key.
  """
  def delete(%__MODULE__{root: root}, key) do
    path = path_for(root, key)
    File.rm(path)
  end

  @doc """
  Checks if a file exists for the given key.
  """
  def exists?(%__MODULE__{root: root}, key) do
    path = path_for(root, key)
    File.exists?(path)
  end

  @doc """
  Returns the file path for a given key.
  """
  def url(%__MODULE__{root: root}, key) do
    # For local storage, return the file path
    # In a web context, this might be served through a controller
    path_for(root, key)
  end

  defp path_for(root, key), do: Path.join(root, key)

  defp default_root, do: Path.expand("priv/storage")
end
