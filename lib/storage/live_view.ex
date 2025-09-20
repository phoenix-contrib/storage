defmodule Storage.LiveView do
  @moduledoc """
  Phoenix LiveView helpers for file uploads.
  """

  @doc """
  Consumes uploaded entries and creates Storage blobs.

  ## Examples

      def handle_event("save", %{"user" => user_params}, socket) do
        uploaded_files =
          consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
            {:ok, Storage.LiveView.consume_uploaded_entry(path, entry)}
          end)

        # Use uploaded_files with your changeset...
      end

  """
  def consume_uploaded_entry(path, entry) do
    Storage.Uploader.put!(path, 
      filename: entry.client_name,
      content_type: entry.client_type
    )
  end

  @doc """
  Consumes uploaded entries for a has_many_attached relationship.

  ## Examples

      def handle_event("save", %{"post" => post_params}, socket) do
        images =
          consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
            {:ok, Storage.LiveView.consume_uploaded_entry(path, entry)}
          end)

        Storage.Attachment.attach_many(post, :images, images)
      end

  """
  def consume_uploaded_entries_for_attachment(socket, upload_name, record, attachment_name) do
    Phoenix.LiveView.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
      blob = consume_uploaded_entry(path, entry)
      {:ok, blob}
    end)
    |> case do
      blobs when is_list(blobs) ->
        Storage.Attachment.attach_many(record, attachment_name, blobs)
        blobs
      
      blob ->
        Storage.Attachment.attach_one(record, attachment_name, blob)
        blob
    end
  end

  @doc """
  Helper for generating file upload configuration.

  ## Examples

      def mount(_params, _session, socket) do
        socket =
          socket
          |> allow_upload(:images, Storage.LiveView.upload_options(
            accept: ~w(.jpg .jpeg .png),
            max_entries: 5,
            max_file_size: 5_000_000
          ))
        
        {:ok, socket}
      end

  """
  def upload_options(opts \\ []) do
    defaults = [
      accept: :any,
      max_entries: 1,
      max_file_size: 10_000_000,  # 10MB
      chunk_size: 64_000,
      progress: &__MODULE__.handle_progress/3,
      auto_upload: false
    ]

    Keyword.merge(defaults, opts)
  end

  @doc """
  Default progress handler for uploads.
  """
  def handle_progress(:avatar, entry, socket) do
    if entry.done? do
      # Upload is complete, you can process it here if needed
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_progress(_upload_name, _entry, socket) do
    {:noreply, socket}
  end
end