# Phoenix Contrib Storage S3

S3-compatible storage provider for `phoenix_contrib_storage`.

This package provides a unified interface for S3-compatible storage services including:

- **Amazon S3** - The original S3 service
- **Cloudflare R2** - Zero egress fees, global distribution
- **DigitalOcean Spaces** - Simple, scalable object storage
- **MinIO** - High-performance, self-hosted object storage
- **Backblaze B2** - Low-cost cloud storage (via S3-compatible API)
- **Custom S3-compatible services**

## Installation

Add both the core storage package and the S3 provider to your `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_contrib_storage, "~> 0.1"},
    {:phoenix_contrib_storage_s3, "~> 0.1"}
  ]
end
```

## Configuration Examples

### AWS S3

```elixir
config :my_app, MyApp.Storage,
  repo: MyApp.Repo,
  services: %{
    s3: %{
      service: StorageS3.Service,
      configuration: %{
        provider: :aws,
        bucket: System.fetch_env!("AWS_S3_BUCKET"),
        region: System.fetch_env!("AWS_REGION"),
        access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
      }
    }
  },
  service: :s3
```

### Cloudflare R2

```elixir
config :my_app, MyApp.Storage,
  repo: MyApp.Repo,
  services: %{
    r2: %{
      service: StorageS3.Service,
      configuration: %{
        provider: :cloudflare_r2,
        account_id: System.fetch_env!("CLOUDFLARE_ACCOUNT_ID"),
        bucket: System.fetch_env!("R2_BUCKET"),
        region: "auto",
        access_key_id: System.fetch_env!("R2_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("R2_SECRET_ACCESS_KEY"),
        public_url_template: "https://your-r2-domain.com/{key}"
      }
    }
  },
  service: :r2
```

### DigitalOcean Spaces

```elixir
config :my_app, MyApp.Storage,
  repo: MyApp.Repo,
  services: %{
    spaces: %{
      service: StorageS3.Service,
      configuration: %{
        provider: :digitalocean_spaces,
        bucket: System.fetch_env!("SPACES_BUCKET"),
        region: System.fetch_env!("SPACES_REGION"), # e.g., "nyc3"
        access_key_id: System.fetch_env!("SPACES_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("SPACES_SECRET_ACCESS_KEY")
      }
    }
  },
  service: :spaces
```

### MinIO (Self-hosted)

```elixir
config :my_app, MyApp.Storage,
  repo: MyApp.Repo,
  services: %{
    minio: %{
      service: StorageS3.Service,
      configuration: %{
        provider: :minio,
        endpoint: "http://localhost:9000",
        bucket: "my-bucket",
        region: "us-east-1",
        access_key_id: System.fetch_env!("MINIO_ACCESS_KEY"),
        secret_access_key: System.fetch_env!("MINIO_SECRET_KEY"),
        public_url_template: "http://localhost:9000/my-bucket/{key}"
      }
    }
  },
  service: :minio
```

### Custom S3-compatible Provider

```elixir
config :my_app, MyApp.Storage,
  repo: MyApp.Repo,
  services: %{
    custom: %{
      service: StorageS3.Service,
      configuration: %{
        provider: :custom,
        endpoint: "https://s3.example.com",
        bucket: "my-bucket",
        region: "us-east-1",
        access_key_id: System.fetch_env!("CUSTOM_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("CUSTOM_SECRET_ACCESS_KEY"),
        public_url_template: "https://cdn.example.com/{key}"
      }
    }
  },
  service: :custom
```

## Configuration Options

### Required Fields

- `bucket` - The bucket/container name
- `access_key_id` - Your access key ID
- `secret_access_key` - Your secret access key

### Optional Fields

- `provider` - Provider preset (`:aws`, `:cloudflare_r2`, `:digitalocean_spaces`, `:minio`, `:custom`)
- `region` - The region/location (defaults to "us-east-1")
- `endpoint` - Custom endpoint (required for `:minio` and `:custom` providers)
- `account_id` - Account ID (required for Cloudflare R2)
- `public_url_template` - Template for public URLs with `{key}` placeholder

## Usage

Once configured, you can use the service through your storage facade:

```elixir
# Get the S3 service
s3_service = MyApp.Storage.get_service!(:s3)

# Store a file
{:ok, key} = StorageS3.Service.put(s3_service, "my-file.txt", "Hello, S3!")

# Store with options
{:ok, key} = StorageS3.Service.put(s3_service, "image.jpg", image_binary, 
  content_type: "image/jpeg",
  metadata: %{"uploaded_by" => "user123"},
  acl: "public-read"
)

# Read a file
{:ok, content} = StorageS3.Service.get(s3_service, "my-file.txt")

# Check if file exists
exists = StorageS3.Service.exists?(s3_service, "my-file.txt")

# Get public URL
url = StorageS3.Service.url(s3_service, "my-file.txt")

# Generate presigned URL (expires in 1 hour by default)
{:ok, presigned_url} = StorageS3.Service.presigned_url(s3_service, "my-file.txt")

# Generate presigned URL with custom expiration (24 hours)
{:ok, presigned_url} = StorageS3.Service.presigned_url(s3_service, "my-file.txt", expires_in: 86400)

# Delete a file
:ok = StorageS3.Service.delete(s3_service, "my-file.txt")
```

## Provider-Specific Notes

### Amazon S3
- Uses standard S3 endpoints
- Supports all S3 features
- Public URLs work automatically

### Cloudflare R2
- Zero egress fees
- Requires `account_id` in configuration
- For public URLs, configure a custom domain and use `public_url_template`
- Uses "auto" region

### DigitalOcean Spaces
- S3-compatible with standard pricing
- Specify region (e.g., "nyc3", "fra1", "sgp1")
- Public URLs work with bucket.region.digitaloceanspaces.com format

### MinIO
- Self-hosted S3-compatible storage
- Requires `endpoint` configuration
- Must provide `public_url_template` for public URLs
- Great for development and on-premises deployments

## Features

- ✅ Store and retrieve files
- ✅ Store with custom content type and metadata
- ✅ Check file existence
- ✅ Delete files
- ✅ Generate public URLs (provider-dependent)
- ✅ Generate presigned URLs for temporary access
- ✅ Update object metadata
- ✅ Multiple provider presets
- ✅ Custom endpoint support
- ✅ Flexible URL templates

## Error Handling

The service returns standard Elixir patterns:

- `{:ok, result}` for successful operations
- `{:error, reason}` for failures
- `:ok` for operations that don't return data (like delete)

Common error reasons:
- `:enoent` - File not found
- `{:http_error, status, body}` - HTTP errors from the provider
- Network and authentication errors are passed through from ExAws