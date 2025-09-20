# Complete Phoenix Application Example
# This shows how to integrate Storage into a full Phoenix application

# ============================================================================
# 1. Configuration (config/config.exs)
# ============================================================================

# config :phoenix_contrib_storage,
#   repo: MyApp.Repo,
#   default_service: :local,
#   services: %{
#     local: {Storage.Services.Local, root: "priv/storage"},
#     s3: {Storage.Services.S3, 
#       bucket: "my-app-storage",
#       region: "us-east-1",
#       access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
#       secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"}
#     }
#   }

# ============================================================================
# 2. Router (lib/my_app_web/router.ex)
# ============================================================================

# defmodule MyAppWeb.Router do
#   use MyAppWeb, :router
#   
#   pipeline :browser do
#     plug :accepts, ["html"]
#     plug :fetch_session
#     plug :fetch_live_flash
#     plug :put_root_layout, {MyAppWeb.LayoutView, :root}
#     plug :protect_from_forgery
#     plug :put_secure_browser_headers
#   end
#   
#   scope "/", MyAppWeb do
#     pipe_through :browser
#     
#     live "/", HomeLive, :index
#     live "/posts", PostLive.Index, :index
#     live "/posts/new", PostLive.Index, :new
#     live "/posts/:id", PostLive.Show, :show
#     live "/posts/:id/edit", PostLive.Show, :edit
#   end
#   
#   # Storage file serving
#   scope "/storage" do
#     forward "/", Storage.Plug, cache_control: "public, max-age=31536000"
#   end
#   
#   # Alternative: use Storage.Controller for more control
#   # scope "/files", MyAppWeb do
#   #   get "/:key", Storage.Controller, :serve
#   #   get "/:key/:filename", Storage.Controller, :serve_with_filename
#   #   get "/:key/download", Storage.Controller, :download
#   # end
# end

# ============================================================================
# 3. Schema with Attachments (lib/my_app/blog/post.ex)
# ============================================================================

defmodule MyApp.Blog.Post do
  use Ecto.Schema
  use Storage.Attachment
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "posts" do
    field :title, :string
    field :content, :string
    field :published_at, :naive_datetime

    # Storage attachments
    has_one_attached :featured_image
    has_many_attached :gallery_images
    has_many_attached :documents

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :content, :published_at])
    |> validate_required([:title, :content])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_length(:content, min: 10)
  end

  def with_attachments(query \\ __MODULE__) do
    # Helper to preload attachments efficiently
    # Note: This would require custom preloading logic
    query
  end

  def image_variants do
    %{
      thumb: [resize: "150x150"],
      medium: [resize: "600x400"],
      large: [resize: "1200x800"]
    }
  end
end

# ============================================================================
# 4. LiveView for Post Management (lib/my_app_web/live/post_live/form_component.ex)
# ============================================================================

defmodule MyAppWeb.PostLive.FormComponent do
  use MyAppWeb, :live_component

  alias MyApp.Blog
  alias MyApp.Blog.Post

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{post: post} = assigns, socket) do
    changeset = Blog.change_post(post)

    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, changeset)
      |> allow_upload(:featured_image, Storage.LiveView.upload_options(
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 1,
        max_file_size: 5_000_000
      ))
      |> allow_upload(:gallery_images, Storage.LiveView.upload_options(
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 10,
        max_file_size: 5_000_000
      ))
      |> allow_upload(:documents, Storage.LiveView.upload_options(
        accept: ~w(.pdf .doc .docx .txt .md),
        max_entries: 5,
        max_file_size: 10_000_000
      ))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      socket.assigns.post
      |> Blog.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.action, post_params)
  end

  defp save_post(socket, :edit, post_params) do
    # Process uploads
    featured_image = consume_upload(socket, :featured_image)
    gallery_images = consume_uploads(socket, :gallery_images)
    documents = consume_uploads(socket, :documents)

    case Blog.update_post_with_attachments(
      socket.assigns.post, 
      post_params,
      featured_image: featured_image,
      gallery_images: gallery_images,
      documents: documents
    ) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_post(socket, :new, post_params) do
    # Process uploads
    featured_image = consume_upload(socket, :featured_image)
    gallery_images = consume_uploads(socket, :gallery_images)
    documents = consume_uploads(socket, :documents)

    case Blog.create_post_with_attachments(
      post_params,
      featured_image: featured_image,
      gallery_images: gallery_images,  
      documents: documents
    ) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp consume_upload(socket, upload_name) do
    consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
      case Storage.put_file(path, 
        filename: entry.client_name,
        content_type: entry.client_type
      ) do
        {:ok, blob} -> {:ok, blob}
        {:error, reason} -> {:postpone, reason}
      end
    end)
    |> List.first()
  end

  defp consume_uploads(socket, upload_name) do
    consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
      case Storage.put_file(path,
        filename: entry.client_name,
        content_type: entry.client_type
      ) do
        {:ok, blob} -> {:ok, blob}
        {:error, reason} -> {:postpone, reason}
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        let={f}
        for={@changeset}
        id="post-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save">

        <.input field={f[:title]} type="text" label="Title" />
        <.input field={f[:content]} type="textarea" label="Content" rows="10" />

        <!-- Featured Image Upload -->
        <div class="field">
          <label class="label">Featured Image</label>
          
          <!-- Current Featured Image -->
          <%= if @post.featured_image_attached?(@post) do %>
            <div class="mb-4">
              <img src={Storage.Variant.Helper.image_tag(@post.featured_image(@post), resize: "300x200")} 
                   alt="Featured image" 
                   class="image" />
            </div>
          <% end %>

          <div class="file" phx-drop-target={@uploads.featured_image.ref}>
            <.live_file_input upload={@uploads.featured_image} class="file-input" />
            <label class="file-label">
              <span class="file-cta">
                <span class="file-label">Choose featured image...</span>
              </span>
            </label>
          </div>

          <!-- Upload Progress -->
          <%= for entry <- @uploads.featured_image.entries do %>
            <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>
          <% end %>
        </div>

        <!-- Gallery Images Upload -->
        <div class="field">
          <label class="label">Gallery Images</label>
          
          <div class="file" phx-drop-target={@uploads.gallery_images.ref}>
            <.live_file_input upload={@uploads.gallery_images} class="file-input" />
            <label class="file-label">
              <span class="file-cta">
                <span class="file-label">Choose gallery images...</span>
              </span>
            </label>
          </div>

          <!-- Upload Progress -->
          <%= for entry <- @uploads.gallery_images.entries do %>
            <div class="mb-2">
              <span><%= entry.client_name %></span>
              <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>
            </div>
          <% end %>
        </div>

        <!-- Documents Upload -->
        <div class="field">
          <label class="label">Documents</label>
          
          <div class="file" phx-drop-target={@uploads.documents.ref}>
            <.live_file_input upload={@uploads.documents} class="file-input" />
            <label class="file-label">
              <span class="file-cta">
                <span class="file-label">Choose documents...</span>
              </span>
            </label>
          </div>

          <!-- Upload Progress -->
          <%= for entry <- @uploads.documents.entries do %>
            <div class="mb-2">
              <span><%= entry.client_name %></span>
              <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>
            </div>
          <% end -->
        </div>

        <div class="field">
          <.button type="submit" phx-disable-with="Saving...">
            <%= if @action == :new, do: "Create Post", else: "Update Post" %>
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end

# ============================================================================
# 5. Context Functions (lib/my_app/blog.ex)
# ============================================================================

defmodule MyApp.Blog do
  import Ecto.Query, warn: false
  alias MyApp.Repo
  alias MyApp.Blog.Post

  def create_post_with_attachments(attrs, attachment_opts \\ []) do
    Repo.transaction(fn ->
      case create_post(attrs) do
        {:ok, post} ->
          attach_files_to_post(post, attachment_opts)
          post

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def update_post_with_attachments(%Post{} = post, attrs, attachment_opts \\ []) do
    Repo.transaction(fn ->
      case update_post(post, attrs) do
        {:ok, updated_post} ->
          attach_files_to_post(updated_post, attachment_opts)
          updated_post

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp attach_files_to_post(post, opts) do
    # Attach featured image
    if featured_image = opts[:featured_image] do
      Storage.Attachment.purge_attached(post, :featured_image)
      Storage.Attachment.attach_one(post, :featured_image, featured_image)
    end

    # Attach gallery images
    if gallery_images = opts[:gallery_images] do
      Storage.Attachment.attach_many(post, :gallery_images, gallery_images)
    end

    # Attach documents
    if documents = opts[:documents] do
      Storage.Attachment.attach_many(post, :documents, documents)
    end
  end

  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end
end