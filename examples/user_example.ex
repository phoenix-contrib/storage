defmodule MyApp.User do
  @moduledoc """
  Example of how to use Storage with an Ecto schema.
  """
  
  use Ecto.Schema
  use Storage.Attachment
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :name, :string
    field :email, :string

    # Storage attachments
    has_one_attached :avatar
    has_many_attached :documents

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
  end

  @doc """
  Example of handling file uploads in a changeset.
  """
  def changeset_with_avatar(user, attrs, avatar_upload \\ nil) do
    changeset = changeset(user, attrs)

    case avatar_upload do
      nil -> 
        changeset
      
      upload ->
        case Storage.put_file(upload.path, filename: upload.filename) do
          {:ok, blob} ->
            # Store the blob ID so we can attach it after insert/update
            put_change(changeset, :avatar_blob_id, blob.id)
          
          {:error, _} ->
            add_error(changeset, :avatar, "failed to upload")
        end
    end
  end

  @doc """
  Example of attaching files after a successful insert/update.
  """
  def attach_avatar(%__MODULE__{} = user, blob_id) when is_binary(blob_id) do
    case MyApp.Repo.get(Storage.Blob, blob_id) do
      nil -> {:error, :blob_not_found}
      blob -> 
        Storage.Attachment.attach_one(user, :avatar, blob)
        {:ok, user}
    end
  end

  @doc """
  Example usage in a Phoenix controller or LiveView.
  """
  def example_usage do
    # Create a user
    {:ok, user} = 
      %__MODULE__{}
      |> changeset(%{name: "John Doe", email: "john@example.com"})
      |> MyApp.Repo.insert()

    # Upload and attach an avatar
    {:ok, blob} = Storage.put_file("/path/to/avatar.jpg", filename: "avatar.jpg")
    Storage.Attachment.attach_one(user, :avatar, blob)

    # Upload and attach multiple documents
    {:ok, doc1} = Storage.put_file("/path/to/doc1.pdf", filename: "resume.pdf")
    {:ok, doc2} = Storage.put_file("/path/to/doc2.pdf", filename: "cover_letter.pdf")
    Storage.Attachment.attach_many(user, :documents, [doc1, doc2])

    # Check if files are attached
    IO.puts("Avatar attached: #{user.avatar_attached?(user)}")
    IO.puts("Documents attached: #{user.documents_attached?(user)}")

    # Get attached files
    avatar = user.avatar(user)
    documents = user.documents(user)

    # Generate URLs
    if avatar do
      avatar_url = Storage.Blob.url(avatar)
      IO.puts("Avatar URL: #{avatar_url}")
    end

    # List document URLs
    Enum.each(documents, fn doc ->
      url = Storage.Blob.url(doc)
      IO.puts("Document: #{doc.filename} - #{url}")
    end)

    {:ok, user}
  end
end