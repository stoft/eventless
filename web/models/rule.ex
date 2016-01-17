defmodule Eventless.Rule do

  defstruct id: "",
    description: "",
    expiration: 0,
    is_active: true
    # updated_at
    # created_at

  def to_struct(map) do
    map = Enum.reduce(map, %{}, fn({k,v}, acc) ->
      cond do
        is_atom(k) -> Map.put(acc, k, v)
        true -> Map.put(acc, String.to_existing_atom(k), v)
      end
    end)
    struct = Kernel.struct(__MODULE__, map)
    # TODO
    # %{struct| description: String.to_integer(struct.expiration)}
  end

  def changeset(struct, map) do
    changeset = to_struct map
    Map.merge(struct, changeset, fn(k, v1, v2) ->
      if k == :id do
        v1
      else
        v2
      end
    end)
  end

end
