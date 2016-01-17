defmodule Eventless.RuleView do
  use Eventless.Web, :view

  def render("index.json", %{rules: rules}) do
    %{data: render_many(rules, Eventless.RuleView, "rule.json")}
  end

  def render("show.json", %{rule: rule}) do
    %{data: render_one(rule, Eventless.RuleView, "rule.json")}
  end

  def render("rule.json", %{rule: rule}) do
    %{id: rule.id}
    rule
  end
end
