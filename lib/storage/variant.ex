defmodule Storage.Variant do
  @moduledoc """
  Handles image transformations and variants.

  Variants allow you to create different versions of images on-demand,
  similar to Rails ActiveStorage variants.

  ## Examples

      # Create a thumbnail variant
      thumbnail = Storage.Variant.processed(blob, resize: "100x100")

      # Create multiple variants
      variants = %{
        thumb: [resize: "100x100"],
        medium: [resize: "300x300"], 
        large: [resize: "800x600"]
      }

      processed_variants = Storage.Variant.process_variants(blob, variants)

  """

  defstruct [:blob, :transformations, :processed]

  @type t :: %__MODULE__{
    blob: Storage.Blob.t(),
    transformations: keyword(),
    processed: boolean()
  }

  @doc """
  Creates a new variant with the given transformations.
  """
  def new(%Storage.Blob{} = blob, transformations) when is_list(transformations) do
    %__MODULE__{
      blob: blob,
      transformations: transformations,
      processed: false
    }
  end

  @doc """
  Processes a variant and returns the processed blob.
  """
  def processed(%Storage.Blob{} = blob, transformations) do
    variant = new(blob, transformations)
    process_variant(variant)
  end

  @doc """
  Processes multiple variants of a blob.
  """
  def process_variants(%Storage.Blob{} = blob, variants) when is_map(variants) do
    Enum.reduce(variants, %{}, fn {name, transformations}, acc ->
      variant = processed(blob, transformations)
      Map.put(acc, name, variant)
    end)
  end

  @doc """
  Generates a variant key for caching.
  """
  def variant_key(%__MODULE__{blob: blob, transformations: transformations}) do
    transform_string = 
      transformations
      |> Enum.map(fn {key, value} -> "#{key}-#{value}" end)
      |> Enum.join("_")
    
    "#{blob.key}_variant_#{:crypto.hash(:md5, transform_string) |> Base.encode16(case: :lower)}"
  end

  def variant_key(%Storage.Blob{} = blob, transformations) do
    new(blob, transformations) |> variant_key()
  end

  @doc """
  Checks if a variant exists in storage.
  """
  def exists?(%__MODULE__{} = variant) do
    key = variant_key(variant)
    service_name = variant.blob.service_name

    case Storage.Services.get_file(service_name, key) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Gets the URL for a variant, processing it if necessary.
  """
  def url(%__MODULE__{} = variant, opts \\ []) do
    if exists?(variant) do
      key = variant_key(variant)
      Storage.Services.url(variant.blob.service_name, key, opts)
    else
      # Process the variant and return URL
      processed_variant = process_variant(variant)
      key = variant_key(processed_variant)
      Storage.Services.url(variant.blob.service_name, key, opts)
    end
  end

  # Private functions

  defp process_variant(%__MODULE__{blob: blob, transformations: transformations} = variant) do
    unless Storage.Blob.image?(blob) do
      raise ArgumentError, "Variants can only be created for images"
    end

    variant_key = variant_key(variant)
    
    # Check if variant already exists
    if exists?(variant) do
      %{variant | processed: true}
    else
      # Process the image
      case Storage.get_file(blob) do
        {:ok, image_data} ->
          processed_data = apply_transformations(image_data, transformations)
          
          # Store the processed variant
          case Storage.Services.put_file(blob.service_name, variant_key, processed_data) do
            :ok -> %{variant | processed: true}
            {:error, reason} -> raise "Failed to store variant: #{inspect(reason)}"
          end

        {:error, reason} ->
          raise "Failed to load original image: #{inspect(reason)}"
      end
    end
  end

  defp apply_transformations(image_data, transformations) do
    # This is a simplified implementation
    # In a real implementation, you'd use a library like Image or Vix
    
    Enum.reduce(transformations, image_data, fn {operation, params}, data ->
      apply_transformation(data, operation, params)
    end)
  end

  defp apply_transformation(image_data, :resize, size) when is_binary(size) do
    # Parse size like "100x100" or "100x100^" or "100x100!"
    case String.split(size, "x") do
      [width, height] ->
        # In a real implementation, you'd use an image processing library
        # For now, just return the original data
        simulate_resize(image_data, String.to_integer(width), parse_height(height))

      _ ->
        raise ArgumentError, "Invalid resize format: #{size}"
    end
  end

  defp apply_transformation(image_data, :quality, quality) when is_integer(quality) do
    # Simulate quality adjustment
    # In reality, you'd use an image library to adjust JPEG quality
    simulate_quality_adjustment(image_data, quality)
  end

  defp apply_transformation(image_data, :format, format) when is_binary(format) do
    # Simulate format conversion
    # In reality, you'd convert between image formats
    simulate_format_conversion(image_data, format)
  end

  defp apply_transformation(image_data, operation, params) do
    # Log unsupported operations
    IO.warn("Unsupported transformation: #{operation} with params #{inspect(params)}")
    image_data
  end

  # Simulation functions (replace with real image processing)
  
  defp parse_height(height_str) do
    height_str
    |> String.replace(~r/[^\d]/, "")
    |> String.to_integer()
  end

  defp simulate_resize(image_data, _width, _height) do
    # In a real implementation, use Image.resize/3 or similar
    image_data
  end

  defp simulate_quality_adjustment(image_data, _quality) do
    # In a real implementation, adjust JPEG quality
    image_data
  end

  defp simulate_format_conversion(image_data, _format) do
    # In a real implementation, convert between formats
    image_data
  end

  @doc """
  Helper for common transformations in templates.

  ## Examples

      <%= Storage.Variant.Helper.image_tag(blob, resize: "100x100", alt: "Thumbnail") %>

  """
  defmodule Helper do
    @moduledoc """
    Template helpers for variants.
    """

    @doc """
    Generates an image tag with variant processing.
    """
    def image_tag(%Storage.Blob{} = blob, opts \\ []) do
      {transformations, html_opts} = Keyword.split(opts, [:resize, :quality, :format])
      
      src = 
        if Enum.empty?(transformations) do
          Storage.Blob.url(blob)
        else
          Storage.Variant.processed(blob, transformations) |> Storage.Variant.url()
        end

      alt = Keyword.get(html_opts, :alt, blob.filename)
      
      Phoenix.HTML.Tag.img_tag(src, Keyword.put(html_opts, :alt, alt))
    end

    @doc """
    Common variant presets.
    """
    def preset(:thumbnail), do: [resize: "150x150"]
    def preset(:small), do: [resize: "300x300"]
    def preset(:medium), do: [resize: "600x600"]
    def preset(:large), do: [resize: "1200x1200"]
    def preset(:avatar), do: [resize: "100x100"]
    def preset(:hero), do: [resize: "1920x1080"]
  end
end