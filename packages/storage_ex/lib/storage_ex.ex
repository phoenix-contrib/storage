defmodule StorageEx do
  @moduledoc """
  StorageEx facade macro with caching and real service initialization.

  ## Setup

  To use `StorageEx`, define a facade module in your application:

      defmodule MyApp.StorageEx do
        use StorageEx, otp_app: :my_app
      end

  This generates helpers such as `MyApp.Storage.repo/0`, `MyApp.Storage.services/0`,
  and `MyApp.StorageEx.get_service!/1`.

  ## Configuration

  All configuration should live in `runtime.exs`, **not** in `config.exs`.
  This ensures your application works correctly in releases and can read values
  from the environment at startup.

  ### Shape of the config

  Each facade (like `MyApp.StorageEx`) expects configuration under
  `config :my_app, MyApp.StorageEx`.
  The config should include:

    * `:repo` — your Ecto repo module (required if you use database tables)
    * `:services` — a map of named services
    * `:service` — the default service name to use (optional, defaults to `:local`)

  Example `runtime.exs` with **S3-compatible service** (Cloudflare R2):

      config :my_app, MyApp.StorageEx,
        repo: MyApp.Repo,
        services: %{
          r2: %{
            service: StorageExS3.Service,
            configuration: %{
              provider: :cloudflare_r2,
              account_id: System.fetch_env!("CLOUDFLARE_ACCOUNT_ID"),
              bucket: System.fetch_env!("R2_BUCKET"),
              access_key_id: System.fetch_env!("R2_ACCESS_KEY_ID"),
              secret_access_key: System.fetch_env!("R2_SECRET_ACCESS_KEY")
            }
          }
        }

  By default, if you don't configure anything, a local service will be added automatically:

      local: %{
        service: StorageEx.Services.Local,
        configuration: %{root: "priv/storage"}
      }

  ### Default service

  You can configure which service to use by default.
  For example, in `prod.exs`:

      config :my_app, MyApp.StorageEx, service: :r2

  Then calls like `MyApp.StorageEx.default_service/0` or higher-level helpers will use that bucket.

  In development and test, you may choose to rely on the default local service,
  which is always present.

  ## Example usage

      # Write a file to the default service
      MyApp.StorageEx.get_service!(MyApp.StorageEx.default_service())
      |> StorageEx.Services.put_file("hello.txt", "hello world")

      # Explicitly fetch a named service
      s3 = MyApp.StorageEx.get_service!(:my_s3_bucket)
      StorageEx.Services.put_file(s3, "avatar.png", File.read!("avatar.png"))
  """

  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote bind_quoted: [otp_app: otp_app] do
      @otp_app otp_app

      @doc """
      Returns the configured repo module.
      """
      def repo do
        get_config().repo ||
          raise "StorageEx repo not configured. Please set `config #{@otp_app}, #{__MODULE__}, repo: MyApp.Repo`"
      end

      @doc """
      Returns the map of initialized services.
      """
      def services do
        get_config().services
      end

      @doc """
      Returns the default service name.
      """
      def default_service do
        get_config().service
      end

      @doc """
      Fetches a specific service struct by name (atom).
      Raises if the service is missing.
      """
      def get_service!(name) when is_atom(name) do
        case services()[name] do
          nil -> raise ArgumentError, "Unknown storage service #{inspect(name)}"
          service -> service
        end
      end

      @doc """
      Reloads the config from application env (useful in tests).
      """
      def reload_config do
        :persistent_term.erase({__MODULE__, :config})
        :ok
      end

      # Cached config in persistent_term
      defp get_config do
        case :persistent_term.get({__MODULE__, :config}, :not_set) do
          :not_set ->
            cfg =
              Application.get_env(@otp_app, __MODULE__, [])
              |> normalize_config()
              |> build_services()

            :persistent_term.put({__MODULE__, :config}, cfg)
            cfg

          cfg ->
            cfg
        end
      end

      defp normalize_config(opts) do
        services = Map.get(opts, :services, %{})

        services =
          if Map.has_key?(services, :local) do
            services
          else
            Map.put(services, :local, %{
              service: StorageEx.Services.Local,
              configuration: %{root: "priv/storage"}
            })
          end

        %{
          repo: Keyword.get(opts, :repo),
          services: services,
          service: Keyword.get(opts, :service, :local)
        }
      end

      defp build_services(%{services: configs} = cfg) do
        services =
          configs
          |> Enum.map(fn {name, %{service: mod, configuration: config}} ->
            case mod.new(config) do
              %^mod{} = service ->
                {name, service}

              {:error, reason} ->
                IO.warn("Skipping misconfigured service #{name}: #{inspect(reason)}")
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> Map.new()

        %{cfg | services: services}
      end
    end
  end
end
