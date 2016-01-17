defmodule Eventless.Repo do

  alias Eventless.Backend

  def insert(struct) do
    id = Backend.insert(struct, :id)
    {:ok, Backend.get(id)}
  end

  def get!(_struct, id) do
    id = cond do
      is_integer id -> id
      is_binary id  -> String.to_integer(id) 
    end
    Backend.get(id)
  end

  def all(struct) do
    Backend.get |> Enum.filter(&(Map.get(&1, :__struct__) == struct))
  end

  def update(struct) do
    Backend.update(struct, struct.id)
    {:ok, Backend.get(struct.id)}
  end

  def delete!(struct) do
    Backend.delete(struct.id)
  end

end
