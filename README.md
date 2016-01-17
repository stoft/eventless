# Eventless

An example of quick prototyping with Elm and Elixir/Phoenix using an Agent as database thus avoiding ecto/database dependencies. The prototype uses all of the normal HTTP operations (GET, POST, PUT, DELETE). It does not use channels/websockets (sorry).

## Background

As a hobby probject I wanted to prototype an Elm frontend for a backend at work that had not yet been built, so I also needed to prototype a backend that could serve Elm and provide the JSON services Elm would need to invoke. Elixir's [Phoenix Framework](http://phoenixframework.org/) seemed like a perfect fit. I wanted to avoid any extra dependencies where possible so I decided to replace Ecto and a DB with an [Agent](http://elixir-lang.org/docs/stable/elixir/Agent.html), "a simple abstraction around state".

## The Prototype Use Case

The prototype use case is of an event management application that collects events, extracts their type and assigns simple rules for how to handle them. The prototype use case differs somewhat from the real world use case but it covers the same ground (multiple entities, JSON/HTTP) to fulfill its purpose of teaching me Elm.

The prototype is only concerned with associating events to, or dissociating events from, rules. An example domain would be events from sensor devices.

Zero or more events may be associated with a single rule.

An event consists of the following fields:

|| Field | Description |
| Id | A numeric ID in the backend. |
| Type | A unique name for a certain type of events. |
| LastSeen | When the event was last seen. |
| RuleId | A foreign key to a rule. |

A rule consists of the following fields:

|| Field | Description |
| Id | A numeric ID in the backend |
| Description | A description of the rule |
| Expiration | How long an associated event should be kept before it is considered expired |
| IsActive | Whether a rule is active or not. |

## The Backend - Phoenix + Elixir.Agent

The backend is a vanilla phoenix application generated using `mix phoenix.new --no-ecto`. The JSON/HTTP services were generated using `mix phoenix.gen.json --no-model`, perhaps creating more work for me but avoiding Ecto's Model/Schema.

Not having Ecto I had to somehow replace `Repo` and also create my own models. Not wanting to re-write too much of the generated controllers (aside from the code needed to associate events with rules) I decided to build a simple drop in replacement `Repo` that exposes the exact same functions but calls my `Agent` instead. In retrospect I probably could've unified `Repo` and the Agent.

Having to build my own models I decided I would use the same tactic there and provide them with their own simple `changeset` functions. Despite some code duplication in each model it worked out pretty well.

The Agent I dubbed `Backend` and wrapped a `map` in it thus creating a key-value store. In the agent's `start_link` I added some initial data so that it wouldn't just be empty (especially since the frontend will have no means for creating events). Lastly I added the agent as a worker to my worker children under `lib/eventless.ex`.

I used [Postman](https://www.getpostman.com) to verify the rest services. I chose Postman over `ExUnit` for educational reasons, I had never used Postman before. It worked out pretty well.

The views I may have made some minor changes to but honestly I don't recall.

The templates I stripped of almost everything and then dropped in Elm following the instructions that [Cultivate/Alan Gardner](http://www.cultivatehq.com/posts/phoenix-elm-1/) kindly put up on their blog.

## The Frontend - Elm

The frontend consists of an Elm application based on `StartApp` and follows the Elm architecture (Model-Update-View-Effects). It uses Bootstrap (as provided by Phoenix) for cosmetics.

It provides functionality for creating rules, associating or dissociating events with/from rules, and deleting both rules and events. It also has a simple filter/search field that allows searching for a specific event.

The model aside from modelling rules and events, also contains fields for error handling (in case an HTTP operation fails), the input fields, search field and similar.

The update function consists of no less than 20 different possible actions. I wouldn't say this part of the code is beautiful, but it works at least.

The view composes several different granular parts that are responsible for displaying the various artifacts.

Being new to Elm the most difficult part of the Frontend was writing the custom HTTP calls using `Http.send` since the standard library only provides `Http.get`, `Http.post` out of the box, and `Http.post` does not set the `Content-Type` header that Phoenix expects. I decided to adapt Elm rather than Phoenix since I had to build a custom calls for PUT and DELETE anyways.

When I started on the frontend I built most of it without calling the backend, simply updating the model, and then once it was complete I started converting the operations to calling the backend. I did this to gain familiarity with Elm one thing at a time instead of confronting many different concepts at once. This may be one of the reasons there was an inflation of actions in the `update` function.
