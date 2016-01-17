module Eventless where

import Effects exposing (Effects, task, Never)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (get)
import Json.Decode as Json exposing ((:=))
import Json.Encode as Encode
import Signal exposing (Address)
import StartApp
import String exposing (toInt)
import Task exposing (Task)

-- MODEL

type alias Model =
  { events : List Event
  , rules : List Rule
  , ruleDescInput : String
  , ruleExpirationInput : String
  , nextRuleID : Int
  , ruleIDToUpdate : Maybe Int
  , selectedRuleID : Maybe Int
  , showDissociatedEvents : Bool
  , searchString : String
  , error : Maybe String
  }

type alias Event =
  { id : Int
  , event_type : String
  , last_seen : String
  , rule_id : Maybe Int
  }

type alias Rule =
  { id : Int
  , description : String
  , expiration : Int
  , isActive : Bool
  }

newRule : String -> Int -> Int -> Rule
newRule description expiration id =
  { description = description
  , expiration = expiration
  , id = id
  , isActive = True
  }

newEvent : String -> String -> Int -> Event
newEvent event_type last_seen id =
  { event_type = event_type
  , last_seen = last_seen
  , rule_id = Nothing
  , id = id
  }

initialModel : Model
initialModel =
  { events = []
  , rules = []
  , ruleDescInput = ""
  , ruleExpirationInput = ""
  , nextRuleID = 3
  , ruleIDToUpdate = Nothing
  , selectedRuleID = Nothing
  , showDissociatedEvents = True
  , searchString = ""
  , error = Nothing
  }

init : (Model, Effects Action)
init =
  (initialModel, Effects.batch [getEvents, getRules])


-- UPDATE

type Action =
  NoOp
  -- RULES
  | AddRule
  | DeleteRule Int
  | EditRule Int
  | RefreshRule
  | RefreshRules (List Rule)
  | SelectRule Int
  | ToggleActiveRule Int
  | UpdateRule
  | UpdateRuleDesc String
  | UpdateRuleExpiration String
  -- EVENTS
  | DeleteEvent Int
  | AssociateEventToRule Int
  | DissociateEventFromRule Int
  | FilterEvent String
  | RefreshEvent
  | RefreshEvents (List Event)
  -- ERRORS
  | RemoveError
  | AddError String

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp -> (model, Effects.none)

    UpdateRuleDesc content ->
      ({ model | ruleDescInput = content }
      , Effects.none)

    UpdateRuleExpiration content ->
      ({ model | ruleExpirationInput = content }
      , Effects.none)

    DeleteRule id ->
      let
        remainingRules = List.filter (\r -> r.id /= id) model.rules
        ruleToDelete = List.filter (\r -> r.id == id) model.rules
          |> List.head
        transformEvent id event =
          if event.rule_id == Just id then
            { event | rule_id = Nothing }
          else
            event
        transformEvents = List.map (transformEvent id) model.events
      in
        case ruleToDelete of
          Nothing -> (model, Effects.none)
          Just rule ->
            ({ model | rules = remainingRules, events = transformEvents }
            , deleteRule rule)

    EditRule id ->
      let
        rule =
          List.filter (\r -> r.id == id) model.rules
          |> List.head
      in
        case rule of
          Nothing -> (model, Effects.none)
          Just rule ->
            ({ model | ruleIDToUpdate = Just rule.id
            , ruleDescInput = rule.description
            , ruleExpirationInput = toString rule.expiration
            }
            , Effects.none)

    SelectRule id ->
      case model.selectedRuleID of
        Just oldId ->
          if oldId == id then
            ({ model | selectedRuleID = Nothing }
            , Effects.none)
          else
            ({ model | selectedRuleID = Just id }
            , Effects.none)

        Nothing ->
          ({ model | selectedRuleID = Just id }
          , Effects.none)

    AddRule ->
      let
        ruleToAdd =
          newRule model.ruleDescInput (parseInt model.ruleExpirationInput) model.nextRuleID
        isInvalid model =
          String.isEmpty model.ruleDescInput || String.isEmpty model.ruleExpirationInput
      in
        if isInvalid model then
          (model, Effects.none)
        else
          ({ model | ruleDescInput = "", ruleExpirationInput = ""}
          , createRule ruleToAdd)

    ToggleActiveRule id ->
      let
        ruleToUpdate = List.filter (\r -> r.id == id) model.rules
          |> List.head
      in
        case ruleToUpdate of
          Just rule -> (model, updateRule {rule | isActive = (not rule.isActive)})
          Nothing -> (model, Effects.none)

    UpdateRule ->
      let
        expiration = parseInt model.ruleExpirationInput
        description = model.ruleDescInput
        transformRule rule =
          if model.ruleIDToUpdate == Just rule.id then
            { rule | description = description
                , expiration = expiration }
          else
            rule

        transformedRules = List.map transformRule model.rules
        transformedRule = List.filter (\r -> Just r.id == model.ruleIDToUpdate) transformedRules
          |> List.head |> Maybe.withDefault (newRule "" 0 0)
        isInvalid model =
          String.isEmpty model.ruleDescInput || String.isEmpty model.ruleExpirationInput
      in
        if isInvalid model then
          ({ model | ruleIDToUpdate = Nothing }, Effects.none)
        else
          ({ model | ruleDescInput = ""
            , ruleExpirationInput = ""
            , rules = transformedRules
            , ruleIDToUpdate = Nothing
          }
          , updateRule transformedRule)

    DeleteEvent id ->
      let
        remainingEvents = List.filter (\e -> e.id /= id) model.events
        eventToDelete = List.filter (\e -> e.id == id) model.events |> List.head
      in
        case eventToDelete of
          Nothing -> (model, Effects.none)
          Just event ->
            ({ model | events = remainingEvents }
            , deleteEvent event)

    AssociateEventToRule id ->
      let
        transformEvent id event =
          if id == event.id then
            { event | rule_id = model.selectedRuleID }
          else
            event
        transformedEvents = List.map (transformEvent id) model.events
        eventToUpdate = List.filter (\e -> e.id == id) model.events
          |> List.head
      in
        case eventToUpdate of
          Nothing -> (model, Effects.none)
          Just event ->
            ({ model | events = transformedEvents }
            , updateEvent (transformEvent id event))

    DissociateEventFromRule id ->
      let
        transformEvent id event =
          if id == event.id then
            { event | rule_id = Nothing }
          else
            event
        transformedEvents = List.map (transformEvent id) model.events
        eventToUpdate = List.filter (\e -> e.id == id) model.events
          |> List.head
      in
        case eventToUpdate of
          Nothing -> (model, Effects.none)
          Just event ->
            ({ model | events = transformedEvents }
            , updateEvent (transformEvent id event))

    FilterEvent content ->
      ({ model | searchString = content }
      , Effects.none)

    RefreshEvent ->
      (model, getEvents)

    RefreshEvents events ->
      ({ model | events = events }
      , Effects.none )

    RefreshRule ->
      (model, getRules)

    RefreshRules rules ->
      ({model| rules = rules}
      , Effects.none)

    RemoveError ->
      ({model | error = Nothing}, Effects.none)


    AddError err ->
      ({model | error = Just err}, Effects.none)


-- VIEW

view : Address Action -> Model -> Html
view address model =
  div [ ]
    [ div [class "row" ] [ navBar address model ]
    , errorView address model
    , div [ class "row" ]
        [ div [class "col-lg-12" ]
            [ ruleView address model
            , eventView address model]
        ]
    ]

navBar : Address Action -> Model -> Html
navBar address model =
  div
    [ class "navbar navbar-fixed-top navbar-inverse" ]
    [ div
        [ class "navbar-brand"] [ text "Eventless" ]
    , Html.form
        [ class "navbar-form form-inline navbar-right" ]
        [ div [ class "form-group"] [eventFilterForm address model] ]
    , div [] []
    ]

errorView : Address Action -> Model -> Html
errorView address model =
  let
    alertBox =
      case model.error of
          Nothing -> [ text "" ]
          Just err ->
            [text ("Oops! " ++ err)
            , button
                [ type' "button", class "close"
                , onClick address RemoveError
                ]
                [ text "x" ]
            ]
    in
      div [ class "alert alert-danger" ] alertBox


eventView : Address Action -> Model -> Html
eventView address model =
  let
    searchEvent event =
      model.searchString == ""
      || String.contains model.searchString event.event_type
    dissociatedEvents =
      model.events
      |> List.filter (\e -> e.rule_id == Nothing)
      |> List.filter searchEvent
    associatedEvents =
      model.events
      |> List.filter (\e -> e.rule_id == model.selectedRuleID && e.rule_id /= Nothing)
      |> List.filter searchEvent
  in
    div [ ]
      [ div [ class "panel panel-warning"]
          [ div [ class "panel-heading"] [ h3 [ class "panel-title" ] [ text "Unruly Events" ] ]
          , (eventList address dissociatedEvents)
          ]
      , div [class "panel panel-info"]
          [ div [ class "panel-heading" ] [ h3 [ class "panel-title" ] [ text "Ruled Events" ] ]
          , (eventList address associatedEvents)
          ]
      ]

eventFilterForm : Address Action -> Model -> Html
eventFilterForm address model =
  input
    [ type' "text"
    , class "form-control"
    , placeholder "Filter Events..."
    , Html.Attributes.value model.searchString
    , name "search"
    , autofocus True
    , onInput address FilterEvent
    ]
    []

eventItem : Address Action -> Event -> Html
eventItem address event =
  tr [ class "small" ]
    [ td [] [ text (toString event.id) ]
    , td [] [ text event.event_type ]
    , td [] [ text event.last_seen ]
    , td []
        [ button
          [ class "btn btn-danger btn-xs"
          , onClick address (DeleteEvent event.id)
          ]
          [ text "✖ Delete" ]
        , if event.rule_id == Nothing then
            button
              [ class "btn btn-success btn-xs"
              , onClick address (AssociateEventToRule event.id)
              ]
              [ text "+ Add to Rule" ]
          else
            button
              [ class "btn btn-success btn-xs"
              , onClick address (DissociateEventFromRule event.id)
              ]
              [ text "- Remove from Rule" ]
        ]
    ]

eventList : Address Action -> List Event -> Html
eventList address events =
  let
    eventItems = List.map (eventItem address) events
    theader = tr []
                [ th [] [ text "ID" ]
                , th [] [ text "Event Type" ]
                , th [] [ text "Last Seen" ]
                , th [] [ text "Operations" ]
                ]
  in
    table [ class "table table-condensed" ] [ thead [] [theader], tbody [] eventItems]


ruleView : Address Action -> Model -> Html
ruleView address model =
    div [ class "panel panel-success"]
      [ div [ class "panel-heading"]
          [ h4 [class "panel-title" ] [text "Rules"] ]
          , div [ class "panel-body" ] [ ruleForm address model ]
          , (ruleList address model.rules model.selectedRuleID)
      ]

ruleForm : Address Action -> Model -> Html
ruleForm address model =
  Html.form [ class "form-horizontal" ]
    [ div
        [ class "form-group col-lg-6" ]
        [ label [ for "ruleName", class "sr-only" ] [ text "Rule Name"]
        , input
          [ type' "text"
          , id "ruleName"
          , class "form-control"
          , placeholder "Rule Name"
          , Html.Attributes.value model.ruleDescInput
          , name "description"
          , onInput address UpdateRuleDesc
          ]
          []
        ]
    , div [ class "form-group col-lg-4" ]
        [ label [ for "minOccurs", class "sr-only" ] [ text "Min.Occurs" ]
        , div [ class "input-group" ] [
         input
            [ type' "number"
            , id "minOccurs"
            , class "form-control col-lg-5"
            , placeholder "Min. occurrence"
            , Html.Attributes.value model.ruleExpirationInput
            , name "expiration"
            , onInput address UpdateRuleExpiration
            ]
            []
        , div [ class "input-group-addon" ] [ text "(s)"]
        ]
        ]
    , div [class "col-lg-2" ] [
    if model.ruleIDToUpdate == Nothing then
        button [ class "btn btn-default btn-md", onClick address AddRule ]
          [ text "Add Rule"]
      else
        button [ class "btn btn-info btn-md", onClick address UpdateRule ]
          [ text "Update Rule"]
    ]
    ]

ruleItem : Address Action -> Maybe Int -> Rule -> Html
ruleItem address selectedRuleID rule =
  let
    isSelected =
      case selectedRuleID of
        Just id -> id == rule.id
        Nothing -> False
    setOnClick = onClick address (SelectRule rule.id)
    setStyle = style [("cursor", "pointer")]
  in
    tr
      [ classList [("bg-primary", isSelected)] ]
        [ td [ setOnClick, setStyle ] [ text (toString rule.id) ]
        , td [ setOnClick, setStyle ] [ text rule.description ]
        , td [ setOnClick, setStyle ] [ text (toString rule.expiration) ]
        , td [ ]
            [ input
                [ type' "checkbox"
                , checked rule.isActive
                , onClick address (ToggleActiveRule rule.id)
                ] []
            ]
        , td []
          [ button
              [ class "btn btn-warning btn-xs", onClick address (EditRule rule.id) ]
              [ text "⚙ Modify" ]
              , button
              [ class "btn btn-danger btn-xs", onClick address (DeleteRule rule.id) ]
              [ text "✖ Delete"]
          ]
        ]

ruleList : Address Action -> List Rule -> Maybe Int -> Html
ruleList address rules selectedRuleID =
  let
    ruleItems = List.map (ruleItem address selectedRuleID) rules
    theader = tr [ ]
        [ th [] [ text "ID" ]
        , th [] [ text "Name" ]
        , th [] [ text "Expiration (s)" ]
        , th [] [ text "Active" ]
        , th [] [ text "Operations" ]
        ]
  in
    table [ class "table" ]
      [ thead [] [theader], tbody [] ruleItems ]

-- UTILS

onInput : Address a -> (String -> a) -> Attribute
onInput address f =
  on "input" targetValue (\v -> Signal.message address (f v))


parseInt : String -> Int
parseInt string =
  case String.toInt string of
    Ok value ->
      value
    Err error ->
      0

-- EFFECTS

getEvents : Effects Action
getEvents =
  Http.get decodeEvents "/api/events"
    |> Task.toResult
    |> Task.map
          (\result ->
            case result of
              Ok events -> RefreshEvents events
              Err err -> AddError (toString err)
          )
    |> Effects.task

getRules : Effects Action
getRules =
  Http.get decodeRules "/api/rules"
    |> Task.toResult
    |> Task.map
        (\result ->
          case result of
            Ok rules -> RefreshRules rules
            Err err -> AddError (toString err)
        )
    |> Effects.task

updateEvent : Event -> Effects Action
updateEvent event =
  Http.send Http.defaultSettings (put (encodeEvent event) ("/api/events/" ++ (toString event.id)))
    |> Task.toResult
    |> Task.map
        (\result ->
          case result of
            Ok _ -> RefreshEvent
            Err err -> AddError (toString err)
        )
    |> Effects.task

updateRule: Rule -> Effects Action
updateRule rule =
  Http.send Http.defaultSettings (put (encodeRule rule) ("/api/rules/" ++ (toString rule.id)))
    |> Task.toResult
    |> Task.map
        (\result ->
          case result of
            Ok _ -> RefreshRule
            Err err -> AddError (toString err)
        )
    |> Effects.task

createRule : Rule -> Effects Action
createRule rule =
  Http.send Http.defaultSettings (post (encodeRule rule) "/api/rules")
    |> Task.toResult
    |> Task.map (\result ->
        case result of
          Ok _ -> RefreshRule
          Err err -> AddError (toString err)
        )
    |> Effects.task

deleteEvent : Event -> Effects Action
deleteEvent event =
  Http.send Http.defaultSettings (delete (encodeEvent event) ("/api/events/" ++ (toString event.id)))
    |> Task.toResult
    |> Task.map (\result ->
          case result of
            Ok _ -> RefreshEvent
            Err err -> AddError (toString err)
          )
    |> Effects.task

deleteRule : Rule -> Effects Action
deleteRule rule =
  Http.send Http.defaultSettings (delete (encodeRule rule) ("/api/rules/" ++ (toString rule.id)))
    |> Task.toResult
    |> Task.map
        (\result ->
          case result of
            Ok _ -> RefreshRule
            Err err -> AddError (toString err)
        )
    |> Effects.task

post : String -> String -> Http.Request
post json url =
  { verb = "POST"
  , headers = [ ("Content-Type", "application/json") ]
  , url = url
  , body = Http.string json
  }

put : String -> String -> Http.Request
put json url =
  { verb = "PUT"
  , headers = [ ("Content-Type", "application/json") ]
  , url = url
  , body = Http.string json
  }

delete : String -> String -> Http.Request
delete json url =
  { verb = "DELETE"
  , headers = [ ("Content-Type", "application/json") ]
  , url = url
  , body = Http.string json
  }

decodeEvents : Json.Decoder (List Event)
decodeEvents =
  let
    event = Json.object4 Event
      ("id" := Json.int)
      ("event_type" := Json.string)
      ("last_seen" := Json.string)
      ("rule_id" := maybeInt Json.int)
  in
    "data" := Json.list event

encodeEvent : Event -> String
encodeEvent event =
  let
    base = Encode.object
      [ ("event_type", Encode.string event.event_type )
      , ("last_seen", Encode.string event.last_seen)
      , ("rule_id", maybeIntEncoder event.rule_id)
      , ("id", Encode.int event.id)
      ]
    wrapper = Encode.object [ ("event", base) ]
  in
    Encode.encode 0 wrapper

encodeRule : Rule -> String
encodeRule rule =
  let
    base = Encode.object
      [ ("description", Encode.string rule.description)
      , ("expiration", Encode.int rule.expiration)
      , ("id", Encode.int rule.id)
      , ("is_active", Encode.bool rule.isActive)
      ]
    wrapper = Encode.object [ ("rule", base) ]
  in
    Encode.encode 0 wrapper


decodeRules : Json.Decoder (List Rule)
decodeRules =
  "data" := Json.list decodeRule

decodeRule : Json.Decoder Rule
decodeRule =
  Json.object4 Rule
    ("id" := Json.int)
    ("description" := Json.string)
    ("expiration" := Json.int)
    ("is_active" := Json.bool)

maybeIntEncoder : (Maybe Int) -> Encode.Value
maybeIntEncoder value =
  case value of
    Nothing -> Encode.null
    Just val -> Encode.int val

maybeInt : Json.Decoder a -> Json.Decoder (Maybe a)
maybeInt decoder =
  Json.oneOf
  [ Json.null Nothing
  , Json.map Just decoder
  ]

-- PORTS

port tasks : Signal (Task.Task Never ())
port tasks =
  app.tasks

-- WIRE THE APP TOGETHER!

main : Signal Html
main =
  app.html

app : StartApp.App Model
app =
  StartApp.start
    { init = init
    -- , model = initialModel
    , view = view
    , update = update
    , inputs = []
    }
