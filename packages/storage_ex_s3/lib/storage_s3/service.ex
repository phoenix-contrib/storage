defmodule StorageExS3.Service do
  @moduledoc """
  S3-compatible storage service.

  This service works with any S3-compatible storage provider including:
  - Amazon S3
  - Cloudflare R2
  - DigitalOcean Spaces
  - MinIO
  - Backblaze B2 (with S3-compatible API)
  - And many others

  The service uses the ExAws S3 client and can be configured for different providers
  using provider presets or custom endpoint configurations.
  """
  use StorageEx.Service

  defstruct [:config, :ex_aws_config, :provider]

  @type t :: %__MODULE__{
          config: map(),
          ex_aws_config: keyword(),
          provider: atom()
        }

  @impl true
  def new(config) when is_map(config) do
    with {:ok, bucket} <- fetch_required(config, :bucket),
         {:ok, access_key_id} <- fetch_required(config, :access_key_id),
         {:ok, secret_access_key} <- fetch_required(config, :secret_access_key) do

      provider = Map.get(config, :provider, :aws)
      region = Map.get(config, :region, "us-east-1")

      # Get provider-specific configuration
      provider_config = get_provider_config(provider, config)

      ex_aws_config = [
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        region: region
      ] ++ provider_config

      %__MODULE__{
        config: %{
          bucket: bucket,
          provider: provider,
          region: region,
          public_url_template: Map.get(config, :public_url_template)
        },
        ex_aws_config: ex_aws_config,
        provider: provider
      }
    else
      {:error, field} ->
        {:error, "Missing required configuration field: #{field}"}
    end
  end

  @doc """
  Stores a file (binary data) at the given key.
  """
  def put(%__MODULE__{config: %{bucket: bucket}, ex_aws_config: aws_config}, key, binary) when is_binary(binary) do
    ExAws.S3.put_object(bucket, key, binary)
    |> ExAws.request(aws_config)
    |> case do
      {:ok, _response} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stores a file with additional options (content type, metadata, etc.).
  """
  def put(%__MODULE__{config: %{bucket: bucket}, ex_aws_config: aws_config}, key, binary, opts) when is_binary(binary) do
    put_request = ExAws.S3.put_object(bucket, key, binary)

    put_request =
      put_request
      |> maybe_add_content_type(opts)
      |> maybe_add_metadata(opts)
      |> maybe_add_acl(opts)

    put_request
    |> ExAws.request(aws_config)
    |> case do
      {:ok, _response} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Reads a file by key.
  """
  def get(%__MODULE__{config: %{bucket: bucket}, ex_aws_config: aws_config}, key) do
    ExAws.S3.get_object(bucket, key)
    |> ExAws.request(aws_config)
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, {:http_error, 404, _}} -> {:error, :enoent}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a file by key.
  """
  def delete(%__MODULE__{config: %{bucket: bucket}, ex_aws_config: aws_config}, key) do
    ExAws.S3.delete_object(bucket, key)
    |> ExAws.request(aws_config)
    |> case do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if a file exists for the given key.
  """
  def exists?(%__MODULE__{config: %{bucket: bucket}, ex_aws_config: aws_config}, key) do
    ExAws.S3.head_object(bucket, key)
    |> ExAws.request(aws_config)
    |> case do
      {:ok, _response} -> true
      {:error, {:http_error, 404, _}} -> false
      {:error, _reason} -> false
    end
  end

  @doc """
  Returns a public URL for the given key.

  Uses provider-specific URL patterns or a custom template if configured.
  """
  def url(%__MODULE__{config: config}, key) do
    case config.public_url_template do
      nil -> build_provider_url(config, key)
      template -> String.replace(template, "{key}", key)
    end
  end

  @doc """
  Generates a presigned URL for temporary access to an object.
  """
  def presigned_url(%__MODULE__{config: %{bucket: bucket}, ex_aws_config: aws_config}, key, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600) # 1 hour default

    ExAws.S3.presigned_url(aws_config, :get, bucket, key, expires_in: expires_in)
    |> case do
      {:ok, url} -> {:ok, url}
      error -> error
    end
  end

  @impl true
  def update_metadata(%__MODULE__{config: %{bucket: bucket}, ex_aws_config: aws_config}, key, metadata) do
    # For S3, we can update object metadata using copy_object with new metadata
    ExAws.S3.put_object_copy(bucket, key, bucket, key, metadata: metadata.custom || %{})
    |> ExAws.request(aws_config)
    |> case do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Provider-specific configurations ---

  defp get_provider_config(:aws, _config) do
    [
      scheme: "https://",
      host: "s3.amazonaws.com",
      port: 443
    ]
  end

  defp get_provider_config(:cloudflare_r2, config) do
    account_id = Map.fetch!(config, :account_id)
    [
      scheme: "https://",
      host: "#{account_id}.r2.cloudflarestorage.com",
      port: 443
    ]
  end

  defp get_provider_config(:digitalocean_spaces, config) do
    region = Map.get(config, :region, "nyc3")
    [
      scheme: "https://",
      host: "#{region}.digitaloceanspaces.com",
      port: 443
    ]
  end

  defp get_provider_config(:minio, config) do
    endpoint = Map.fetch!(config, :endpoint)
    [scheme, host_port] = String.split(endpoint, "://", parts: 2)

    case String.split(host_port, ":", parts: 2) do
      [host, port] ->
        [
          scheme: "#{scheme}://",
          host: host,
          port: String.to_integer(port)
        ]
      [host] ->
        port = if scheme == "https", do: 443, else: 80
        [
          scheme: "#{scheme}://",
          host: host,
          port: port
        ]
    end
  end

  defp get_provider_config(:custom, config) do
    endpoint = Map.fetch!(config, :endpoint)
    [scheme, host_port] = String.split(endpoint, "://", parts: 2)

    case String.split(host_port, ":", parts: 2) do
      [host, port] ->
        [
          scheme: "#{scheme}://",
          host: host,
          port: String.to_integer(port)
        ]
      [host] ->
        port = if scheme == "https", do: 443, else: 80
        [
          scheme: "#{scheme}://",
          host: host,
          port: port
        ]
    end
  end

  # --- URL builders ---

  defp build_provider_url(%{provider: :aws, bucket: bucket, region: region}, key) do
    "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
  end

  defp build_provider_url(%{provider: :cloudflare_r2, bucket: bucket}, key) do
    # R2 public URLs need custom domain configuration
    # This is a placeholder - users should configure public_url_template
    "https://your-r2-domain.com/#{key}"
  end

  defp build_provider_url(%{provider: :digitalocean_spaces, bucket: bucket, region: region}, key) do
    "https://#{bucket}.#{region}.digitaloceanspaces.com/#{key}"
  end

  defp build_provider_url(%{provider: :minio}, _key) do
    # MinIO URLs are highly customizable, users should provide public_url_template
    raise "MinIO requires public_url_template configuration"
  end

  defp build_provider_url(%{provider: :custom}, _key) do
    raise "Custom provider requires public_url_template configuration"
  end

  # --- Private helpers ---

  defp fetch_required(config, key) do
    case Map.fetch(config, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, _} -> {:error, key}
      :error -> {:error, key}
    end
  end

  defp maybe_add_content_type(request, opts) do
    case Keyword.get(opts, :content_type) do
      nil -> request
      content_type -> ExAws.S3.put_object(request, [], content_type: content_type)
    end
  end

  defp maybe_add_metadata(request, opts) do
    case Keyword.get(opts, :metadata) do
      nil -> request
      metadata when is_map(metadata) ->
        ExAws.S3.put_object(request, [], metadata: metadata)
    end
  end

  defp maybe_add_acl(request, opts) do
    case Keyword.get(opts, :acl) do
      nil -> request
      acl -> ExAws.S3.put_object(request, [], acl: acl)
    end
  end
end
