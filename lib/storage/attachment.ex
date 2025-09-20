defmodule Storage.Attachment do
  @moduledoc """
  Provides macros for adding file attachments to Ecto schemas.

  This module allows you to easily add file attachment functionality
  to your Ecto schemas, similar to Rails ActiveStorage.

  ## Usage

      defmodule MyApp.User do
        use Ecto.Schema
        use Storage.Attachment

        schema "users" do
          field :name, :string
          has_one_attached :avatar
          has_many_attached :documents
        end
      end

  This will add virtual fields and helper functions for managing attachments.
  """

  defmacro __using__(_opts) do
    quote do
      import Storage.Attachment, only: [has_one_attached: 1, has_many_attached: 1]
      
      @before_compile Storage.Attachment
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Attaches a file to this record.
      """
      def attach(record, attachment_name, blob_or_blobs) do
        Storage.Attachment.attach(record, attachment_name, blob_or_blobs)
      end

      @doc """
      Detaches files from this record.
      """
      def detach(record, attachment_name) do
        Storage.Attachment.detach(record, attachment_name)
      end

      @doc """
      Purges attachments and their blobs from this record.
      """
      def purge_attached(record, attachment_name) do
        Storage.Attachment.purge_attached(record, attachment_name)
      end
    end
  end

  @doc """
  Defines a has_one_attached relationship.
  """
  defmacro has_one_attached(name) do
    quote do
      field unquote(:"#{name}_attachment"), :any, virtual: true
      field unquote(:"#{name}_blob"), :any, virtual: true

      def unquote(:"#{name}_attached?")(%__MODULE__{} = record) do
        Storage.Attachment.attached?(record, unquote(name))
      end

      def unquote(:"attach_#{name}")(%__MODULE__{} = record, blob) do
        Storage.Attachment.attach_one(record, unquote(name), blob)
      end

      def unquote(:"detach_#{name}")(%__MODULE__{} = record) do
        Storage.Attachment.detach_one(record, unquote(name))
      end

      def unquote(:"#{name}")(%__MODULE__{} = record) do
        Storage.Attachment.get_one(record, unquote(name))
      end
    end
  end

  @doc """
  Defines a has_many_attached relationship.
  """
  defmacro has_many_attached(name) do
    quote do
      field unquote(:"#{name}_attachments"), {:array, :any}, virtual: true, default: []
      field unquote(:"#{name}_blobs"), {:array, :any}, virtual: true, default: []

      def unquote(:"#{name}_attached?")(%__MODULE__{} = record) do
        Storage.Attachment.attached?(record, unquote(name))
      end

      def unquote(:"attach_#{name}")(%__MODULE__{} = record, blobs) when is_list(blobs) do
        Storage.Attachment.attach_many(record, unquote(name), blobs)
      end

      def unquote(:"attach_#{name}")(%__MODULE__{} = record, blob) do
        Storage.Attachment.attach_many(record, unquote(name), [blob])
      end

      def unquote(:"detach_#{name}")(%__MODULE__{} = record) do
        Storage.Attachment.detach_many(record, unquote(name))
      end

      def unquote(:"#{name}")(%__MODULE__{} = record) do
        Storage.Attachment.get_many(record, unquote(name))
      end
    end
  end

  # Implementation functions

  @doc """
  Checks if a record has any attachments for the given name.
  """
  def attached?(record, name) do
    case Storage.AttachmentSchema.find_for_record(record, name) do
      nil -> false
      _attachment -> true
    end
  end

  @doc """
  Attaches a single blob to a record.
  """
  def attach_one(record, name, blob) do
    # First detach any existing attachment
    detach_one(record, name)
    
    # Create new attachment
    Storage.AttachmentSchema.create!(record, name, blob)
    
    record
  end

  @doc """
  Attaches multiple blobs to a record.
  """
  def attach_many(record, name, blobs) when is_list(blobs) do
    Enum.each(blobs, fn blob ->
      Storage.AttachmentSchema.create!(record, name, blob)
    end)
    
    record
  end

  @doc """
  Detaches a single attachment without deleting the blob.
  """
  def detach_one(record, name) do
    case Storage.AttachmentSchema.find_for_record(record, name) do
      nil -> :ok
      attachment -> Storage.AttachmentSchema.detach!(attachment)
    end
  end

  @doc """
  Detaches all attachments for a given name without deleting the blobs.
  """
  def detach_many(record, name) do
    attachments = Storage.AttachmentSchema.all_for_record(record, name)
    
    Enum.each(attachments, fn attachment ->
      Storage.AttachmentSchema.detach!(attachment)
    end)
  end

  @doc """
  Gets a single attachment for a record.
  """
  def get_one(record, name) do
    case Storage.AttachmentSchema.find_for_record(record, name) do
      nil -> nil
      attachment -> attachment.blob
    end
  end

  @doc """
  Gets all attachments for a record.
  """
  def get_many(record, name) do
    attachments = Storage.AttachmentSchema.all_for_record(record, name)
    Enum.map(attachments, & &1.blob)
  end

  @doc """
  Purges all attachments and their blobs for a given name.
  """
  def purge_attached(record, name) do
    attachments = Storage.AttachmentSchema.all_for_record(record, name)
    
    Enum.each(attachments, fn attachment ->
      Storage.AttachmentSchema.purge!(attachment)
    end)
  end
end