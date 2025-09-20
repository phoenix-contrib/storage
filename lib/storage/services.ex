defmodule Storage.Services do
  @moduledoc """
  Service abstraction for different storage backends.
  """

  @callback put_file(key :: String.t(), data :: binary() | %{path: String.t()}) :: :ok | {:error, term()}
  @callback get_file(key :: String.t()) :: {:ok, binary()} | {:error, term()}
  @callback delete_file(key :: String.t()) :: :ok | {:error, term()}
  @callback url(key :: String.t(), opts :: keyword()) :: String.t()
  @callback signed_url(key :: String.t(), opts :: keyword()) :: {:ok, String.t()} | {:error, term()}

  @doc """
  Stores a file using the specified service.
  """
  def put_file(service_name, key, data) do
    {module, config} = Storage.Config.service_config(service_name)
    module.put_file(key, data, config)
  end

  @doc """
  Retrieves a file using the specified service.
  """
  def get_file(service_name, key) do
    {module, config} = Storage.Config.service_config(service_name)
    module.get_file(key, config)
  end

  @doc """
  Deletes a file using the specified service.
  """
  def delete_file(service_name, key) do
    {module, config} = Storage.Config.service_config(service_name)
    module.delete_file(key, config)
  end

  @doc """
  Generates a URL for a file using the specified service.
  """
  def url(service_name, key, opts \\ []) do
    {module, config} = Storage.Config.service_config(service_name)
    module.url(key, config, opts)
  end

  @doc """
  Generates a signed URL for a file using the specified service.
  """
  def signed_url(service_name, key, opts \\ []) do
    {module, config} = Storage.Config.service_config(service_name)
    module.signed_url(key, config, opts)
  end
end