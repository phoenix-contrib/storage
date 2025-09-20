defmodule Storage.Config do
  @moduledoc """
  Configuration management for Storage.
  """

  @doc """
  Returns the default service name.
  """
  def default_service do
    Application.get_env(:storage, :default_service, :local)
  end

  @doc """
  Returns all configured services.
  """
  def services do
    Application.get_env(:storage, :services, %{
      local: {Storage.Services.Local, root: "/tmp/storage"}
    })
  end

  @doc """
  Returns the configuration for a specific service.
  """
  def service_config(service_name) do
    case Map.get(services(), service_name) do
      {module, config} -> {module, config}
      nil -> raise ArgumentError, "Service #{inspect(service_name)} not configured"
    end
  end

  @doc """
  Returns the module for a specific service.
  """
  def service_module(service_name) do
    {module, _config} = service_config(service_name)
    module
  end

  @doc """
  Returns the Repo module to use for database operations.
  """
  def repo do
    Application.get_env(:storage, :repo) || raise "Storage repo not configured"
  end
end