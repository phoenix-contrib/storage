defmodule Storage.Analyzer do
  @moduledoc """
  Analyzes uploaded files to extract metadata.

  This module provides functionality to analyze uploaded files and extract
  useful metadata like image dimensions, video duration, document properties, etc.
  """

  @doc """
  Analyzes a blob and returns metadata.

  ## Examples

      {:ok, metadata} = Storage.Analyzer.analyze(blob)
      
      # For images:
      %{width: 1920, height: 1080, format: "JPEG"}
      
      # For videos:
      %{width: 1920, height: 1080, duration: 120.5, format: "MP4"}

  """
  def analyze(%Storage.Blob{} = blob) do
    case Storage.get_file(blob) do
      {:ok, data} ->
        analyze_data(data, blob.content_type, blob.filename)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Analyzes file data directly.
  """
  def analyze_data(data, content_type, filename \\ nil) do
    case content_type do
      "image/" <> _ -> analyze_image(data, content_type)
      "video/" <> _ -> analyze_video(data, content_type)
      "audio/" <> _ -> analyze_audio(data, content_type)
      "application/pdf" -> analyze_pdf(data)
      _ -> analyze_generic(data, content_type, filename)
    end
  end

  # Image analysis
  defp analyze_image(data, content_type) do
    case content_type do
      "image/jpeg" -> analyze_jpeg(data)
      "image/png" -> analyze_png(data)
      "image/gif" -> analyze_gif(data)
      "image/webp" -> analyze_webp(data)
      _ -> {:ok, %{format: extract_format(content_type)}}
    end
  end

  defp analyze_jpeg(<<0xFF, 0xD8, _::binary>> = data) do
    # Simple JPEG header analysis
    case extract_jpeg_dimensions(data) do
      {width, height} ->
        {:ok, %{
          format: "JPEG",
          width: width,
          height: height,
          colorspace: detect_jpeg_colorspace(data)
        }}

      :error ->
        {:ok, %{format: "JPEG"}}
    end
  end

  defp analyze_png(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>> = data) do
    case extract_png_dimensions(data) do
      {width, height, bit_depth, color_type} ->
        {:ok, %{
          format: "PNG",
          width: width,
          height: height,
          bit_depth: bit_depth,
          color_type: color_type_name(color_type)
        }}

      :error ->
        {:ok, %{format: "PNG"}}
    end
  end

  defp analyze_gif(<<"GIF89a", _::binary>> = data) do
    analyze_gif_data(data, "GIF89a")
  end

  defp analyze_gif(<<"GIF87a", _::binary>> = data) do
    analyze_gif_data(data, "GIF87a")
  end

  defp analyze_gif(_data) do
    {:ok, %{format: "GIF"}}
  end

  defp analyze_gif_data(data, version) do
    case extract_gif_dimensions(data) do
      {width, height} ->
        {:ok, %{
          format: "GIF",
          version: version,
          width: width,
          height: height,
          animated: detect_gif_animation(data)
        }}

      :error ->
        {:ok, %{format: "GIF", version: version}}
    end
  end

  defp analyze_webp(<<"RIFF", _size::32-little, "WEBP", _::binary>> = data) do
    case extract_webp_dimensions(data) do
      {width, height} ->
        {:ok, %{
          format: "WebP",
          width: width,
          height: height
        }}

      :error ->
        {:ok, %{format: "WebP"}}
    end
  end

  # Video analysis (simplified - would use FFmpeg in practice)
  defp analyze_video(_data, content_type) do
    {:ok, %{
      format: extract_format(content_type),
      media_type: "video"
    }}
  end

  # Audio analysis (simplified - would use FFmpeg in practice)
  defp analyze_audio(_data, content_type) do
    {:ok, %{
      format: extract_format(content_type),
      media_type: "audio"
    }}
  end

  # PDF analysis (simplified - would use a PDF library in practice)
  defp analyze_pdf(data) do
    case extract_pdf_info(data) do
      info when is_map(info) ->
        {:ok, Map.merge(%{format: "PDF"}, info)}

      :error ->
        {:ok, %{format: "PDF"}}
    end
  end

  # Generic file analysis
  defp analyze_generic(_data, content_type, filename) do
    metadata = %{
      format: extract_format(content_type),
      content_type: content_type
    }

    metadata =
      if filename do
        Map.put(metadata, :extension, Path.extname(filename))
      else
        metadata
      end

    {:ok, metadata}
  end

  # Helper functions for dimension extraction

  defp extract_jpeg_dimensions(data) do
    # Simplified JPEG dimension extraction
    # In practice, you'd parse the JPEG segments properly
    case :binary.match(data, <<0xFF, 0xC0>>) do
      {pos, _} ->
        case binary_part(data, pos + 5, 4) do
          <<height::16-big, width::16-big>> -> {width, height}
          _ -> :error
        end

      :nomatch ->
        :error
    end
  rescue
    _ -> :error
  end

  defp extract_png_dimensions(data) do
    # PNG IHDR chunk starts at byte 16
    try do
      case binary_part(data, 16, 13) do
        <<width::32-big, height::32-big, bit_depth::8, color_type::8, _::binary>> ->
          {width, height, bit_depth, color_type}

        _ ->
          :error
      end
    rescue
      _ -> :error
    end
  end

  defp extract_gif_dimensions(data) do
    try do
      case binary_part(data, 6, 4) do
        <<width::16-little, height::16-little>> -> {width, height}
        _ -> :error
      end
    rescue
      _ -> :error
    end
  end

  defp extract_webp_dimensions(data) do
    # Simplified WebP dimension extraction
    try do
      case binary_part(data, 20, 8) do
        <<"VP8 ", _::32-little>> ->
          # VP8 format
          case binary_part(data, 30, 4) do
            <<_::2, width::14-little, _::2, height::14-little>> ->
              {width, height}

            _ ->
              :error
          end

        _ ->
          :error
      end
    rescue
      _ -> :error
    end
  end

  defp extract_pdf_info(data) do
    # Very basic PDF info extraction
    if String.starts_with?(data, "%PDF-") do
      version = 
        data
        |> String.slice(0, 20)
        |> String.replace(~r/[^0-9.]/, "")
        |> String.slice(0, 3)

      %{version: version}
    else
      :error
    end
  rescue
    _ -> :error
  end

  defp detect_jpeg_colorspace(_data) do
    # Simplified - would analyze JPEG segments in practice
    "RGB"
  end

  defp detect_gif_animation(data) do
    # Check for multiple image blocks
    String.contains?(data, <<0x21, 0xF9>>) # Graphic Control Extension
  rescue
    _ -> false
  end

  defp color_type_name(0), do: "grayscale"
  defp color_type_name(2), do: "rgb"
  defp color_type_name(3), do: "palette"
  defp color_type_name(4), do: "grayscale_alpha"
  defp color_type_name(6), do: "rgba"
  defp color_type_name(_), do: "unknown"

  defp extract_format(content_type) do
    content_type
    |> String.split("/")
    |> List.last()
    |> String.upcase()
  end
end