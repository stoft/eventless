defmodule Eventless.EventView do
  use Eventless.Web, :view

  def render("index.json", %{events: events}) do
    %{data: render_many(events, Eventless.EventView, "event.json")}
  end

  def render("show.json", %{event: event}) do
    %{data: render_one(event, Eventless.EventView, "event.json")}
  end

  def render("event.json", %{event: event}) do
    %{id: event.id}
    event
  end
end
