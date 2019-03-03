defmodule Pow.Plug.Base do
  @moduledoc """
  This plug macro will set `:pow_config` as private, and attempt to fetch and
  assign a user in the connection if it has not already been assigned. The user
  will be assigned automatically in any of the operations.

  ## Example

      defmodule MyAppWeb.Pow.CustomPlug do
        use Pow.Plug.Base

        @impl true
        def fetch(conn, _config) do
          user = fetch_user_from_cookie(conn)

          {conn, user}
        end

        @impl true
        def create(conn, user, _config) do
          conn = update_cookie(conn, user)

          {conn, user}
        end

        @impl true
        def delete(conn, _config) do
          delete_cookie(conn)
        end
      end
  """
  alias Plug.Conn
  alias Pow.{Config, Plug}

  @callback init(Config.t()) :: Config.t()
  @callback call(Conn.t(), Config.t()) :: Conn.t()
  @callback fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  @callback create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  @callback delete(Conn.t(), Config.t()) :: Conn.t()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @doc false
      def init(config), do: config

      @doc """
      Configures the connection for Pow, and fetches user.

      `:plug` is appended to the passed configuration, so the current plug will
      be used in any subsequent calls to create, update and delete user
      credentials from the connection. The configuration is then set for the
      conn with `Pow.Plug.put_config/2`.

      If a user can't be fetched with `Pow.Plug.current_user/2`, `do_fetch/2`
      will be called.
      """
      def call(conn, config) do
        config = put_plug(config)
        conn   = Plug.put_config(conn, config)

        conn
        |> Plug.current_user(config)
        |> maybe_fetch_user(conn, config)
      end

      defp put_plug(config), do: Config.put(config, :plug, __MODULE__)

      @doc """
      Calls `fetch/2` and assigns the current user to the conn.

      The user is assigned to the conn with `Pow.Plug.assign_current_user/3`.
      """
      @spec do_fetch(Conn.t(), Config.t()) :: Conn.t()
      def do_fetch(conn, config) do
        conn
        |> fetch(config)
        |> assign_current_user(config)
      end

      @doc """
      Calls `create/3` and assigns the current user.

      The user is assigned to the conn with `Pow.Plug.assign_current_user/3`.
      """
      @spec do_create(Conn.t(), map(), Config.t()) :: Conn.t()
      def do_create(conn, user, config) do
        conn
        |> create(user, config)
        |> assign_current_user(config)
      end

      @doc """
      Calls `delete/2` and removes the current user assigned to the conn.

      The user assigned is removed from the conn with
      `Pow.Plug.assign_current_user/3`.
      """
      @spec do_delete(Conn.t(), Config.t()) :: Conn.t()
      def do_delete(conn, config) do
        conn
        |> delete(config)
        |> remove_current_user(config)
      end

      defp maybe_fetch_user(nil, conn, config), do: do_fetch(conn, config)
      defp maybe_fetch_user(_user, conn, _config), do: conn

      defp assign_current_user({conn, user}, config), do: Plug.assign_current_user(conn, user, config)

      defp remove_current_user(conn, config), do: Plug.assign_current_user(conn, nil, config)

      defoverridable unquote(__MODULE__)
    end
  end
end
