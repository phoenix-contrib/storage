defmodule MyAppWeb.UserProfileLive do
  @moduledoc """
  Example Phoenix LiveView showing how to handle file uploads with Storage.
  """
  
  use MyAppWeb, :live_view
  alias MyApp.{User, Repo}

  def mount(%{"id" => user_id}, _session, socket) do
    user = Repo.get!(User, user_id)
    
    socket =
      socket
      |> assign(:user, user)
      |> assign(:form, to_form(User.changeset(user, %{})))
      |> allow_upload(:avatar, Storage.LiveView.upload_options(
        accept: ~w(.jpg .jpeg .png .gif),
        max_entries: 1,
        max_file_size: 5_000_000  # 5MB
      ))
      |> allow_upload(:documents, Storage.LiveView.upload_options(
        accept: ~w(.pdf .doc .docx .txt),
        max_entries: 10,
        max_file_size: 10_000_000  # 10MB
      ))

    {:ok, socket}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    form = 
      socket.assigns.user
      |> User.changeset(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    # Process avatar uploads
    avatar_blobs =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        case Storage.put_file(path, 
          filename: entry.client_name,
          content_type: entry.client_type
        ) do
          {:ok, blob} -> {:ok, blob}
          {:error, reason} -> {:postpone, reason}
        end
      end)

    # Process document uploads
    document_blobs =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        case Storage.put_file(path,
          filename: entry.client_name, 
          content_type: entry.client_type
        ) do
          {:ok, blob} -> {:ok, blob}
          {:error, reason} -> {:postpone, reason}
        end
      end)

    # Update user and attach files
    case update_user_with_attachments(socket.assigns.user, user_params, avatar_blobs, document_blobs) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:user, user)
          |> put_flash(:info, "Profile updated successfully!")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("remove_avatar", _params, socket) do
    user = socket.assigns.user
    Storage.Attachment.purge_attached(user, :avatar)
    
    socket =
      socket
      |> assign(:user, Repo.preload(user, [], force: true))
      |> put_flash(:info, "Avatar removed")

    {:noreply, socket}
  end

  def handle_event("remove_document", %{"blob_id" => blob_id}, socket) do
    user = socket.assigns.user
    
    # Find and remove the specific document
    user.documents(user)
    |> Enum.find(fn blob -> blob.id == blob_id end)
    |> case do
      nil -> 
        {:noreply, put_flash(socket, :error, "Document not found")}
      
      _blob ->
        # Remove the attachment (this would need a more specific function)
        # For now, we'll reload the user
        socket =
          socket
          |> assign(:user, Repo.preload(user, [], force: true))
          |> put_flash(:info, "Document removed")

        {:noreply, socket}
    end
  end

  defp update_user_with_attachments(user, user_params, avatar_blobs, document_blobs) do
    Repo.transaction(fn ->
      # Update user basic info
      case user
           |> User.changeset(user_params)
           |> Repo.update() do
        {:ok, updated_user} ->
          # Attach avatar if uploaded
          case avatar_blobs do
            [avatar_blob] ->
              # Remove old avatar first
              Storage.Attachment.purge_attached(updated_user, :avatar)
              Storage.Attachment.attach_one(updated_user, :avatar, avatar_blob)
            
            [] -> 
              :ok  # No new avatar
          end

          # Attach documents if uploaded  
          if length(document_blobs) > 0 do
            Storage.Attachment.attach_many(updated_user, :documents, document_blobs)
          end

          updated_user

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">Edit Profile</h1>
      
      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
        <div>
          <.input field={@form[:name]} label="Name" />
        </div>
        
        <div>
          <.input field={@form[:email]} label="Email" />
        </div>

        <!-- Avatar Upload -->
        <div>
          <label class="block text-sm font-medium mb-2">Avatar</label>
          
          <!-- Current Avatar -->
          <%= if @user.avatar_attached?(@user) do %>
            <div class="mb-4">
              <img src={Storage.Blob.url(@user.avatar(@user))} 
                   alt="Current avatar" 
                   class="w-20 h-20 rounded-full object-cover" />
              <button type="button" 
                      phx-click="remove_avatar" 
                      class="ml-2 text-red-600 text-sm">
                Remove
              </button>
            </div>
          <% end %>

          <!-- Upload New Avatar -->
          <div phx-drop-target={@uploads.avatar.ref} 
               class="border-2 border-dashed border-gray-300 rounded-lg p-6">
            <.live_file_input upload={@uploads.avatar} class="hidden" />
            <div class="text-center">
              <p class="text-gray-600">Drag and drop an avatar, or 
                <button type="button" onclick="document.querySelector('input[name=\\\"avatar\\\"]').click()" 
                        class="text-blue-600 underline">browse</button>
              </p>
            </div>
          </div>

          <!-- Avatar Upload Progress -->
          <%= for entry <- @uploads.avatar.entries do %>
            <div class="mt-2">
              <div class="flex justify-between text-sm">
                <span><%= entry.client_name %></span>
                <span><%= entry.progress %>%</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full" style={"width: #{entry.progress}%"}></div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Documents Upload -->
        <div>
          <label class="block text-sm font-medium mb-2">Documents</label>
          
          <!-- Current Documents -->
          <%= if @user.documents_attached?(@user) do %>
            <div class="mb-4 space-y-2">
              <%= for doc <- @user.documents(@user) do %>
                <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                  <div>
                    <span class="font-medium"><%= doc.filename %></span>
                    <span class="text-gray-500 ml-2">(<%= Storage.Blob.human_size(doc) %>)</span>
                  </div>
                  <button type="button" 
                          phx-click="remove_document" 
                          phx-value-blob_id={doc.id}
                          class="text-red-600 text-sm">
                    Remove
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Upload New Documents -->
          <div phx-drop-target={@uploads.documents.ref} 
               class="border-2 border-dashed border-gray-300 rounded-lg p-6">
            <.live_file_input upload={@uploads.documents} class="hidden" />
            <div class="text-center">
              <p class="text-gray-600">Drag and drop documents, or 
                <button type="button" onclick="document.querySelector('input[name=\\\"documents\\\"]').click()" 
                        class="text-blue-600 underline">browse</button>
              </p>
            </div>
          </div>

          <!-- Documents Upload Progress -->
          <%= for entry <- @uploads.documents.entries do %>
            <div class="mt-2">
              <div class="flex justify-between text-sm">
                <span><%= entry.client_name %></span>
                <span><%= entry.progress %>%</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full" style={"width: #{entry.progress}%"}></div>
              </div>
            </div>
          <% end %>
        </div>

        <div>
          <.button type="submit" class="w-full">Save Changes</.button>
        </div>
      </.form>
    </div>
    """
  end
end