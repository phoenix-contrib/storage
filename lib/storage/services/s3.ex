defmodule Storage.Services.S3 do
  @moduledoc """
  Amazon S3 storage service implementation.

  Requires the following dependencies to be added to your mix.exs:

      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:hackney, "~> 1.18"},
      {:sweet_xml, "~> 0.7"}

  ## Configuration

      config :phoenix_contrib_storage,
        services: %{
          s3: {Storage.Services.S3, 
            bucket: "my-bucket",
            region: "us-east-1",
            access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
            secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"}
          }
        }

  """

  @behaviour Storage.Services

  @impl Storage.Services
  def put_file(key, data, config) do
    bucket = get_config_value(config, :bucket)
    
    file_data = normalize_data(data)
    
    case ExAws.S3.put_object(bucket, key, file_data)
         |> ExAws.request(aws_config(config)) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Storage.Services
  def get_file(key, config) do
    bucket = get_config_value(config, :bucket)
    
    case ExAws.S3.get_object(bucket, key)
         |> ExAws.request(aws_config(config)) do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Storage.Services
  def delete_file(key, config) do
    bucket = get_config_value(config, :bucket)
    
    case ExAws.S3.delete_object(bucket, key)
         |> ExAws.request(aws_config(config)) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Storage.Services
  def url(key, config, opts \\ []) do
    bucket = get_config_value(config, :bucket)
    region = get_config_value(config, :region)
    
    case Keyword.get(opts, :signed, false) do
      true ->
        case signed_url(key, config, opts) do
          {:ok, url} -> url
          {:error, _} -> public_url(bucket, region, key)
        end
      
      false ->
        public_url(bucket, region, key)
    end
  end

  @impl Storage.Services
  def signed_url(key, config, opts \\ []) do
    bucket = get_config_value(config, :bucket)
    expires_in = Keyword.get(opts, :expires_in, 3600)  # 1 hour default
    
    case ExAws.S3.presigned_url(aws_config(config), :get, bucket, key, expires_in: expires_in) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates a signed URL for direct uploads.
  """
  def signed_upload_url(key, config, opts \\ []) do
    bucket = get_config_value(config, :bucket)
    expires_in = Keyword.get(opts, :expires_in, 3600)
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    
    conditions = [
      ["starts-with", "$Content-Type", ""],
      ["content-length-range", 0, Keyword.get(opts, :max_file_size, 100_000_000)]
    ]
    
    case ExAws.S3.presigned_post(aws_config(config), bucket, 
      key: key,
      expires_in: expires_in,
      content_type: content_type,
      conditions: conditions
    ) do
      {:ok, presigned_data} -> {:ok, presigned_data}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists objects in the bucket with optional prefix.
  """
  def list_objects(config, opts \\ []) do
    bucket = get_config_value(config, :bucket)
    prefix = Keyword.get(opts, :prefix, "")
    max_keys = Keyword.get(opts, :max_keys, 1000)
    
    case ExAws.S3.list_objects_v2(bucket, prefix: prefix, max_keys: max_keys)
         |> ExAws.request(aws_config(config)) do
      {:ok, %{body: %{contents: contents}}} -> 
        {:ok, Enum.map(contents, &map_s3_object/1)}
      
      {:error, reason} -> 
        {:error, reason}
    end
  end

  @doc """
  Checks if an object exists in S3.
  """
  def exists?(key, config) do
    bucket = get_config_value(config, :bucket)
    
    case ExAws.S3.head_object(bucket, key)
         |> ExAws.request(aws_config(config)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Gets object metadata without downloading the file.
  """
  def head_object(key, config) do
    bucket = get_config_value(config, :bucket)
    
    case ExAws.S3.head_object(bucket, key)
         |> ExAws.request(aws_config(config)) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp normalize_data(data) when is_binary(data), do: data
  
  defp normalize_data(%{path: path}) do
    File.read!(path)
  end

  defp aws_config(config) do
    base_config = [
      access_key_id: get_config_value(config, :access_key_id),
      secret_access_key: get_config_value(config, :secret_access_key),
      region: get_config_value(config, :region)
    ]

    # Add optional configurations
    config
    |> Keyword.take([:scheme, :host, :port, :http_client])
    |> Keyword.merge(base_config)
  end

  defp get_config_value(config, key) do
    case Keyword.get(config, key) do
      {:system, env_var} -> System.get_env(env_var)
      value -> value
    end
  end

  defp public_url(bucket, region, key) do
    "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
  end

  defp map_s3_object(object) do
    %{
      key: object.key,
      last_modified: object.last_modified,
      etag: object.etag,
      size: object.size,
      storage_class: object.storage_class
    }
  end
end