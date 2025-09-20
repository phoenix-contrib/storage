defmodule Storage.Repo.Migrations.CreateStorageBlobs do
  use Ecto.Migration

  def change do
    create table(:storage_blobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :metadata, :map, default: %{}
      add :service_name, :string, null: false
      add :byte_size, :bigint, null: false
      add :checksum, :string

      timestamps()
    end

    create unique_index(:storage_blobs, [:key])
    create index(:storage_blobs, [:service_name])
    create index(:storage_blobs, [:content_type])
    create index(:storage_blobs, [:filename])
  end
end