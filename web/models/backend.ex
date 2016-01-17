defmodule Eventless.Backend do
  @backend_name :agent_backend

  # Client API

  def get(document_id) do
    Agent.get(@backend_name, &Map.get(&1, document_id))
  end

  def get() do
    Agent.get(@backend_name, &Map.values(&1))
  end

  def insert(document, id_field_name) when is_atom(id_field_name) do
    id = case Agent.get(@backend_name, &Map.keys/1) do
      [] -> 1
      list -> Enum.max(list) + 1
    end

    doc = Map.put document, id_field_name, id
    :ok = Agent.update(@backend_name, &Map.put(&1, id, doc))
    id
  end

  def insert(document, id_field_name) do
    insert(document, String.to_atom(id_field_name))
  end

  def update(document, id) do
    :ok = Agent.update(@backend_name, &Map.put(&1, id, document))
  end

  def delete(document_id) do
    Agent.get_and_update(@backend_name, &Map.pop(&1, document_id))
  end

  ##-------------------------------------------------
  ## Server/Agent Callbacks
  ##-------------------------------------------------

  def start_link do
    rules = Enum.map(1..5, fn(index)->
      %Eventless.Rule{id: index, description: "#{index}h expiration", expiration: index * 3600 }
    end)
    events = Enum.map(6..20, fn(index)->
      %Eventless.Event{id: index, event_type: "IOT.Thingy.Event#{index}", last_seen: "2015-12-31T23:59" }
    end)
    map = Enum.reduce(rules, %{}, fn(item, acc) -> Map.put(acc, item.id, item) end)
    map = Enum.reduce(events, map, fn(item, acc) -> Map.put(acc, item.id, item) end)

    Agent.start_link(fn -> map end, [name: @backend_name])

    # Agent.start_link(fn -> Map.new end, [name: @backend_name])

  end

end
