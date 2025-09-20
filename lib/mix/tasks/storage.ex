defmodule Mix.Tasks.Storage do
  @moduledoc """
  Mix tasks for Storage maintenance.

  ## Available tasks:

  - `mix storage.purge_unattached` - Remove orphaned blobs
  - `mix storage.migrate` - Run Storage migrations
  - `mix storage.analyze` - Analyze and update blob metadata

  """
end

defmodule Mix.Tasks.Storage.PurgeUnattached do
  @moduledoc """
  Purges unattached blobs older than the specified duration.

  ## Usage

      mix storage.purge_unattached
      mix storage.purge_unattached --days 30
      mix storage.purge_unattached --hours 24

  ## Options

  - `--days` - Remove blobs older than N days (default: 7)
  - `--hours` - Remove blobs older than N hours
  - `--dry-run` - Show what would be deleted without actually deleting

  """

  use Mix.Task

  @shortdoc "Purges unattached blobs"

  def run(args) do
    {opts, _} = OptionParser.parse!(args, 
      strict: [days: :integer, hours: :integer, dry_run: :boolean],
      aliases: [d: :days, h: :hours, n: :dry_run]
    )

    # Start the application to ensure repos are available
    Mix.Task.run("app.start")

    older_than = 
      cond do
        opts[:hours] -> %{hours: opts[:hours]}
        opts[:days] -> %{days: opts[:days]}
        true -> %{days: 7}
      end

    if opts[:dry_run] do
      Mix.shell().info("DRY RUN - No files will be deleted")
      count = count_unattached_blobs(older_than)
      Mix.shell().info("Would delete #{count} unattached blobs")
    else
      Mix.shell().info("Purging unattached blobs...")
      count = Storage.purge_unattached(older_than)
      Mix.shell().info("Deleted #{count} unattached blobs")
    end
  end

  defp count_unattached_blobs(older_than) do
    cutoff = DateTime.utc_now() |> DateTime.add(-older_than.days || -older_than.hours * 3600, :second)

    import Ecto.Query
    alias Storage.{Blob, AttachmentSchema}

    query = from b in Blob,
      left_join: a in assoc(b, :attachments),
      where: is_nil(a.id) and b.inserted_at < ^cutoff,
      select: count(b.id)

    Storage.Repo.one(query)
  end
end

defmodule Mix.Tasks.Storage.Migrate do
  @moduledoc """
  Copies Storage migration files to your project.

  ## Usage

      mix storage.migrate

  This will copy the Storage migration files to your `priv/repo/migrations/` directory
  with appropriate timestamps.

  """

  use Mix.Task

  @shortdoc "Copies Storage migrations to your project"

  def run(_args) do
    migrations_path = Application.app_dir(:storage, "priv/repo/migrations")
    target_path = "priv/repo/migrations"

    unless File.exists?(target_path) do
      Mix.shell().error("Target migrations directory does not exist: #{target_path}")
      Mix.shell().info("Make sure you're running this from your Phoenix project root")
      System.halt(1)
    end

    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    migrations = [
      {"001_create_storage_blobs.exs", "#{timestamp}_create_storage_blobs.exs"},
      {"002_create_storage_attachments.exs", "#{timestamp + 1}_create_storage_attachments.exs"}
    ]

    Enum.each(migrations, fn {source, target} ->
      source_file = Path.join(migrations_path, source)
      target_file = Path.join(target_path, target)

      if File.exists?(target_file) do
        Mix.shell().info("Migration already exists: #{target}")
      else
        case File.cp(source_file, target_file) do
          :ok ->
            Mix.shell().info("Copied migration: #{target}")

          {:error, reason} ->
            Mix.shell().error("Failed to copy #{source}: #{reason}")
        end
      end
    end)

    Mix.shell().info("\nRun `mix ecto.migrate` to apply the migrations")
  end
end

defmodule Mix.Tasks.Storage.Analyze do
  @moduledoc """
  Analyzes blobs and updates their metadata.

  ## Usage

      mix storage.analyze
      mix storage.analyze --limit 100
      mix storage.analyze --content-type "image/*"

  ## Options

  - `--limit` - Limit the number of blobs to analyze
  - `--content-type` - Only analyze blobs with matching content type pattern
  - `--force` - Re-analyze blobs that already have metadata

  """

  use Mix.Task

  @shortdoc "Analyzes blobs and updates metadata"

  def run(args) do
    {opts, _} = OptionParser.parse!(args,
      strict: [limit: :integer, content_type: :string, force: :boolean],
      aliases: [l: :limit, c: :content_type, f: :force]
    )

    # Start the application
    Mix.Task.run("app.start")

    import Ecto.Query
    alias Storage.{Blob, Analyzer}

    query = from(b in Blob)

    query = 
      if pattern = opts[:content_type] do
        from b in query, where: like(b.content_type, ^pattern)
      else
        query
      end

    query =
      unless opts[:force] do
        from b in query, where: b.metadata == %{} or is_nil(b.metadata)
      else
        query
      end

    query =
      if limit = opts[:limit] do
        from b in query, limit: ^limit
      else
        query
      end

    blobs = Storage.Repo.all(query)

    total = length(blobs)
    Mix.shell().info("Analyzing #{total} blobs...")

    {success_count, error_count} = 
      blobs
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0}, fn {blob, index}, {success, errors} ->
        Mix.shell().info("Analyzing #{index}/#{total}: #{blob.filename}")

        case Analyzer.analyze(blob) do
          {:ok, metadata} ->
            # Update blob with analyzed metadata
            changeset = Blob.changeset(blob, %{metadata: metadata})
            
            case Storage.Repo.update(changeset) do
              {:ok, _} -> 
                {success + 1, errors}

              {:error, _} ->
                Mix.shell().error("Failed to update blob #{blob.id}")
                {success, errors + 1}
            end

          {:error, reason} ->
            Mix.shell().error("Failed to analyze #{blob.filename}: #{inspect(reason)}")
            {success, errors + 1}
        end
      end)

    Mix.shell().info("\nAnalysis complete:")
    Mix.shell().info("  Successful: #{success_count}")
    Mix.shell().info("  Errors: #{error_count}")
  end
end