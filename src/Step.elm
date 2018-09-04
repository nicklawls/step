module Step exposing (Step, map, stay, orElse, run, to, withCmd, mapMsg, exit, mapExit, onExit, asUpdateFunction, foldSteps)

{-| Some stuff

@docs Step, map, stay, orElse, run, to, withCmd, mapMsg, exit, mapExit, onExit, asUpdateFunction, foldSteps

-}

import Task


{-| Step

A `Step s msg o` describes one step of an interaction. Here's a few things about the interactions we're talking about her

  - Interactions can involve the end user of your app, external servers, javascript: anything you might need to coordinate with in an Elm app
  - Interactions can be in one of a finite set of _states_. The states are represented by the type `s`
  - Interactions change state in response to _messages_, actions from the outside world. The messages are represented by the type `msg`
  - When responding to a message, the state of the interaction might change, and `Cmd`s may be fired, potentially producing more messages.
  - Interactions might go on indefinitely, or end. If they end, they result in a final value of type `o`. This might seem a little weird, but it has some nice properties

`Step s msg o` is inteneded to be the return value of an update function. It encodes a bunch of common update function patterns, uniting them under a simple mental model, that simultaneously reduces boilerplate and eases composition.

-}
type Step s msg o
    = To state (List (Cmd msg))
    | Exit o
    | Stay


{-| Step to a new state in the interaction
-}
to : s -> Step s msg o
to state =
    To state []


{-| Keep the interaction in the state it was in.

NOTE: This will prevent any commands from being returned

    Step.stay == (Step.stay |> Step.withCmd myHttpCall)

If you want to stay in the same state, but run some commands, use `Step.to` explicitly

    Step.to MySameState |> Step.withCmd myHttpCall

-}
stay : Step s msg o
stay =
    Stay


{-| End the interaction by returning a value of type `o`
-}
exit : o -> Step s msg o
exit =
    Exit


{-| If we're stepping `to` a new state, add an action to fire off
-}
withCmd : Cmd msg -> Step s msg o -> Step s msg o
withCmd command step =
    case step of
        To state commands ->
            To state (command :: commands)

        Exit o ->
            Exit o

        Stay ->
            Stay


{-| Apply a function to the state inside a step, if it's there

Most useful in building a bigger step out of a sub-step you happen to have lying around

-}
map : (a -> b) -> Step a msg o -> Step b msg o
map f step =
    case step of
        To state cmd ->
            To (f state) cmd

        Exit o ->
            Exit o

        Stay ->
            Stay


{-| Apply a function to any `msg`s conteined in the step

Also used for building larger interaction steps out of smaller ones

-}
mapMsg : (a -> b) -> Step state a o -> Step state b o
mapMsg f step =
    case step of
        To state msgCmd ->
            To state (List.map (Cmd.map f) msgCmd)

        Exit o ->
            Exit o

        Stay ->
            Stay


{-| Run the first suceeding step, with priority given to the second argument

Intended to be used pipeline style

    Step.to { loading = True } |> Step.orElse (Step.to { loading = False }) == Step.to { loading = True }

    Step.noop |> Step.orElse Step.to { loading = True } == Step.to { loading = True }

-}
orElse : Step s msg o -> Step s msg o -> Step s msg o
orElse stepA stepB =
    case ( stepA, stepB ) of
        ( To _ _, To state commands ) ->
            To state commands

        ( To state commands, Stay ) ->
            To state commands

        ( To state commands, Exit o ) ->
            Exit o

        ( Stay, To state commands ) ->
            To state commands

        ( Stay, Stay ) ->
            Stay

        ( Stay, Exit o ) ->
            Exit o

        ( Exit o, To state commands ) ->
            Exit o

        ( Exit o, Stay ) ->
            Exit o

        ( Exit _, Exit o ) ->
            Exit o


{-| Map over the output of an interaction, if we've reached the end
-}
mapExit : (o -> p) -> Step s msg o -> Step state msg p
mapExit f step =
    case step of
        To state commands ->
            To state commands

        Exit o ->
            Exit (f o)

        Stay ->
            Stay


{-| Choose a step based on the result of another interaction

You can use this in combination with `map` and `mapMsg` to glue the end of one interaction to the beginning of another.

-}
onExit : (o -> Step s msg p) -> Step s msg o -> Step s msg p
onExit f step =
    case step of
        To state commands ->
            To state commands

        Exit o ->
            f o

        Stay ->
            Stay


{-| Turn a Step into the usual TEA update tuple

It must be a step in an interaction that continues forever. We know it is if the type variable `o` isn't a specifc type, and can thus be chosen to be `Never`

-}
run : Step state msg Never -> Maybe ( state, Cmd msg )
run s =
    case s of
        To state commands ->
            Just ( state, Cmd.batch commands )

        Exit n ->
            never n

        Stay ->
            Nothing


{-| turn an update function that returns a `Step` to a normal Elm Architecture update function

uses `run` internally to default with the provided model in case of a `stay`

-}
asUpdateFunction : (msg -> model -> Step model msg Never) -> msg -> model -> ( model, Cmd msg )
asUpdateFunction update msg model =
    update msg model
        |> run
        |> Maybe.withDefault ( model, Cmd.none )


filterMap : (a -> Maybe b) -> Step a msg o -> Step b msg o
filterMap f step =
    case step of
        To state cmds ->
            case f state of
                Just newState ->
                    To newState cmds

                Nothing ->
                    Stay

        Stay ->
            Stay

        Exit o ->
            Exit o


fromMaybe : Maybe a -> Step a msg o
fromMaybe x =
    case x of
        Just s ->
            To s []

        Nothing ->
            Stay


fromUpdate : ( state, Cmd msg ) -> Step s msg o
fromUpdate ( s, cmd ) =
    To s [ cmd ]



-- foo
--     |> Step.withAttempt someFunc task


withAttempt : (Result x a -> msg) -> Task.Task x a -> Step s msg o -> Step s msg o
withAttempt handler task step =
    case step of
        To state cmds ->
            To state (Task.attempt handler task :: cmds)

        Stay ->
            Stay

        Exit o ->
            Exit o


{-| starting from an initial state, fold an update function over a list of messages
-}
foldSteps :
    (msg -> model -> Step model msg o)
    -> Step model msg o
    -> List msg
    -> Step model msg o
foldSteps update init msgs =
    List.foldl (andThen << update) init msgs


andThen : (model1 -> Step model2 msg o) -> Step model1 msg o -> Step model2 msg o
andThen f s =
    case s of
        To state commands ->
            f state |> withCmd (Cmd.batch commands)

        Stay ->
            Stay

        Exit o ->
            Exit o
