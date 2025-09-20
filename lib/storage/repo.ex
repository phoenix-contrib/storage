defmodule Storage.Repo do
  @moduledoc """
  Default repo module for Storage.
  
  This can be overridden by configuring :storage, :repo in your config.
  """

  @doc """
  Delegates to the configured repo.
  """
  def insert(changeset) do
    repo().insert(changeset)
  end

  def insert!(changeset) do
    repo().insert!(changeset)
  end

  def get_by(queryable, clauses) do
    repo().get_by(queryable, clauses)
  end

  def one(queryable) do
    repo().one(queryable)
  end

  def all(queryable) do
    repo().all(queryable)
  end

  def delete(struct) do
    repo().delete(struct)
  end

  def delete!(struct) do
    repo().delete!(struct)
  end

  def preload(struct_or_structs, preloads) do
    repo().preload(struct_or_structs, preloads)
  end

  defp repo do
    case Application.get_env(:phoenix_contrib_storage, :repo) do
      nil -> raise "Storage repo not configured. Please set config :phoenix_contrib_storage, :repo, MyApp.Repo"
      repo -> repo
    end
  end
end