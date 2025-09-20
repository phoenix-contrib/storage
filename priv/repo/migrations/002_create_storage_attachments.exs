defmodule Storage.Repo.Migrations.CreateStorageAttachments do
  use Ecto.Migration

  def change do
    create table(:storage_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :record_type, :string, null: false
      add :record_id, :binary_id, null: false
      add :blob_id, references(:storage_blobs, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:storage_attachments, [:record_type, :record_id])
    create index(:storage_attachments, [:record_type, :record_id, :name])
    create index(:storage_attachments, [:blob_id])
    create unique_index(:storage_attachments, [:record_type, :record_id, :name, :blob_id])
  end
end