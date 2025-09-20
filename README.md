# Storage

[![CI](https://github.com/phoenix-contrib/storage/workflows/CI/badge.svg)](https://github.com/phoenix-contrib/storage/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/phoenix_contrib_storage.svg)](https://hex.pm/packages/phoenix_contrib_storage)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/phoenix_contrib_storage/)
[![Hex.pm Downloads](https://img.shields.io/hexpm/dt/phoenix_contrib_storage.svg)](https://hex.pm/packages/phoenix_contrib_storage)

ActiveStorage-like file storage for Phoenix. All things file uploads for your Phoenix app following the design principles applied in Rails ActiveStorage but adapted to the Phoenix framework.

## Features

- **Multiple storage backends**: Local filesystem, S3, and more
- **Direct uploads**: Signed URLs for client-side uploads
- **Image processing**: Built-in support for variants and transformations
- **Ecto integration**: Seamless attachment associations with your schemas
- **Phoenix LiveView support**: Helper functions for file uploads
- **Configurable**: Easy configuration for different environments

## Installation

Add `phoenix_contrib_storage` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_contrib_storage, "~> 0.1.0"}
  ]
end
```

## Configuration

Add to your `config/config.exs`:

```elixir
config :phoenix_contrib_storage,
  repo: MyApp.Repo,
  default_service: :local,
  services: %{
    local: {Storage.Services.Local, root: "priv/storage"},
    s3: {Storage.Services.S3, bucket: "my-bucket", region: "us-east-1"}
  }
```

## Database Setup

Run the migrations to create the necessary tables:

```bash
mix ecto.gen.migration create_storage_tables
```

Copy the contents from `priv/repo/migrations/` or use the provided migration files.

## Usage

### Basic File Upload

```elixir
# Upload a file
{:ok, blob} = Storage.put_file("/path/to/file.jpg", filename: "avatar.jpg")

# Get file URL
url = Storage.Blob.url(blob)
```

### Schema Integration

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  use Storage.Attachment

  schema "users" do
    field :name, :string
    
    # Single file attachment
    has_one_attached :avatar
    
    # Multiple file attachments
    has_many_attached :documents
    
    timestamps()
  end
end

# Usage
user = MyApp.Repo.get!(User, 1)

# Attach files
Storage.Attachment.attach_one(user, :avatar, blob)
Storage.Attachment.attach_many(user, :documents, [blob1, blob2])

# Check if attached
user.avatar_attached?(user)  # true/false

# Get attachments
avatar = user.avatar(user)
documents = user.documents(user)
```

### Phoenix LiveView Integration

```elixir
defmodule MyAppWeb.UserLive do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:avatar, Storage.LiveView.upload_options(
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 5_000_000
      ))
    
    {:ok, socket}
  end
  
  def handle_event("save", %{"user" => user_params}, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        {:ok, Storage.LiveView.consume_uploaded_entry(path, entry)}
      end)
    
    # Use uploaded_files with your changeset...
    {:noreply, socket}
  end
end
```

### File Serving

Add to your router:

```elixir
# Basic file serving
get "/storage/:key", Storage.Controller, :serve

# With filename for SEO-friendly URLs
get "/storage/:key/:filename", Storage.Controller, :serve_with_filename

# Force download
get "/storage/:key/download", Storage.Controller, :download
```

### Direct Uploads (S3)

```elixir
# Generate signed URL for direct upload
{:ok, upload_url} = Storage.signed_url_for_direct_upload(
  filename: "document.pdf",
  content_type: "application/pdf"
)

# Use in your frontend for direct uploads
```

## Storage Services

### Local Filesystem

```elixir
config :phoenix_contrib_storage,
  services: %{
    local: {Storage.Services.Local, root: "priv/storage"}
  }
```

### Amazon S3

```elixir
config :phoenix_contrib_storage,
  services: %{
    s3: {Storage.Services.S3, 
      bucket: "my-bucket", 
      region: "us-east-1",
      access_key_id: "...",
      secret_access_key: "..."
    }
  }
```

## API Reference

### Storage

- `Storage.put_file/2` - Upload a file and create a blob
- `Storage.get_file/1` - Retrieve file data
- `Storage.delete_file/1` - Delete a file
- `Storage.signed_url_for_direct_upload/1` - Generate signed upload URL

### Storage.Blob

- `Storage.Blob.url/2` - Generate URL for a blob
- `Storage.Blob.image?/1` - Check if blob is an image
- `Storage.Blob.human_size/1` - Get human-readable file size

### Storage.Attachment

- `has_one_attached/1` - Define single file attachment
- `has_many_attached/1` - Define multiple file attachments
- `attach_one/3` - Attach single file to record
- `attach_many/3` - Attach multiple files to record

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

### Development Setup

1. Clone the repository
2. Install dependencies: `mix deps.get`
3. Run tests: `mix test`
4. Check code quality: `mix credo --strict`
5. Check types: `mix dialyzer`
6. Format code: `mix format`

### Code Quality

This project maintains high code quality standards:

- **Tests**: Comprehensive test suite with >90% coverage
- **Linting**: Code linting with Credo in strict mode
- **Type Checking**: Static analysis with Dialyzer
- **Formatting**: Consistent code formatting with `mix format`
- **Documentation**: All public functions are documented
- **CI/CD**: Automated testing, linting, and type checking on all PRs

## License

MIT License. See [LICENSE](LICENSE) for details.
