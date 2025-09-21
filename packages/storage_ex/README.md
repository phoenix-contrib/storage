# Phoenix Contrib Storage

ActiveStorage-like file storage for Phoenix applications. This is the core package that provides the facade pattern, service behavior, and local storage implementation.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_contrib_storage, "~> 0.1"}
  ]
end
```

## Quick Start

1. **Define your storage facade:**

```elixir
defmodule MyApp.Storage do
  use Storage, otp_app: :my_app
end
```

2. **Configure in `runtime.exs`:**

```elixir
config :my_app, MyApp.Storage,
  repo: MyApp.Repo,
  services: %{
    local: %{
      service: Storage.Services.Local,
      configuration: %{root: "priv/storage"}
    }
  },
  service: :local
```

3. **Use in your application:**

```elixir
# Get the local service
local_service = MyApp.Storage.get_service!(:local)

# Store a file
{:ok, key} = Storage.Services.Local.put(local_service, "hello.txt", "Hello, World!")

# Read a file
{:ok, content} = Storage.Services.Local.get(local_service, "hello.txt")
```

## Configuration

All configuration should be in `runtime.exs` to work properly with releases:

```elixir
config :my_app, MyApp.Storage,
  repo: MyApp.Repo,  # Your Ecto repo (required for database operations)
  services: %{
    local: %{
      service: Storage.Services.Local,
      configuration: %{root: "priv/storage"}
    }
  },
  service: :local  # Default service to use
```

### Automatic Local Service

If you don't configure any services, a local service will be automatically added:

```elixir
local: %{
  service: Storage.Services.Local,
  configuration: %{root: "priv/storage"}
}
```

## Services

### Built-in Services

- **Local Storage** (`Storage.Services.Local`) - Stores files on the local filesystem

### External Service Providers

Install additional packages for cloud storage:

- **S3-Compatible** - `{:phoenix_contrib_storage_s3, "~> 0.1"}` (AWS S3, Cloudflare R2, DigitalOcean Spaces, MinIO, etc.)
- **Azure Blob** - `{:phoenix_contrib_storage_azure, "~> 0.1"}` (coming soon)
- **Google Cloud Storage** - `{:phoenix_contrib_storage_gcs, "~> 0.1"}` (coming soon)

## Database Schema

This library requires database tables to store blob metadata and attachments. Generate the migration:

```bash
mix storage.migrate
```

This creates:

- `storage_blobs` - File metadata (key, filename, content_type, etc.)
- `storage_attachments` - Polymorphic associations between your models and blobs
- `storage_variants` - Processed versions of blobs (optional)

## Facade API

Your storage facade (e.g., `MyApp.Storage`) provides:

- `repo/0` - Returns your configured Ecto repo
- `services/0` - Returns a map of initialized service structs
- `default_service/0` - Returns the default service name (atom)
- `get_service!(name)` - Fetches a specific service by name
- `reload_config/0` - Reloads configuration (useful in tests)

## Local Service API

The `Storage.Services.Local` service provides:

- `put(service, key, binary)` - Store a file
- `get(service, key)` - Read a file
- `delete(service, key)` - Delete a file
- `exists?(service, key)` - Check if file exists
- `url(service, key)` - Get file path/URL

## Architecture

This library follows the facade pattern inspired by Oban:

1. **Facade Module** - Your app defines `MyApp.Storage` using the `Storage` macro
2. **Service Behavior** - All storage providers implement `Storage.Service`
3. **Caching** - Configuration is cached in `:persistent_term` for fast access
4. **Explicit Config** - Service modules are explicitly configured (no magic atom mapping)

## Development

The library is organized as an umbrella project:

- `apps/core` - This package (`phoenix_contrib_storage`)
- `apps/cloudflare_r2` - CloudflareR2 provider
- More providers coming soon...

## License

MIT
