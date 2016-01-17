defmodule Eventless.Event do

  defstruct id: nil,
    event_type: "",
    last_seen: "",
    rule_id: nil

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
      changeset = Map.has_key?(map, :__struct__) && map || to_struct map
      Map.merge(struct, changeset, fn(k, v1, v2) ->
        if k == :id do
          v1
        else
          v2
        end
      end)
    end

end
