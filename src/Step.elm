module Step exposing (Step, map, noop, orElse, run, to, withCmd, mapMsg, exit, mapExit, onExit, asUpdateFunction, foldSteps)

{-| Some stuff

@docs Step, map, noop, orElse, run, to, withCmd, mapMsg, exit, mapExit, onExit, asUpdateFunction, foldSteps

-}

import Task


{-| Step

a `Step state msg output` describes one step of a state machine.

On each step, the state machine can either

  - `noop`, staying in the same state and executing no commands
  - step `to` some new `state`, potentially executing `msg`-returning commands
  - `exit`, and return a value of type `output`

-}
type Step state msg output
    = To state (List (Cmd msg))
    | Exit output
    | NoOp


{-| step to a state with no commands
-}
to : state -> Step state msg output
to state =
    To state []


{-| -}
noop : Step state msg output
noop =
    NoOp


{-| -}
withCmd : Cmd msg -> Step state msg output -> Step state msg output
withCmd command step =
    case step of
        To state commands ->
            To state (command :: commands)

        Exit output ->
            Exit output

        NoOp ->
            NoOp


{-| -}
map : (a -> b) -> Step a msg output -> Step b msg output
map f step =
    case step of
        To state cmd ->
            To (f state) cmd

        Exit output ->
            Exit output

        NoOp ->
            NoOp


{-| -}
mapMsg : (a -> b) -> Step state a output -> Step state b output
mapMsg f step =
    case step of
        To state msgCmd ->
            To state (List.map (Cmd.map f) msgCmd)

        Exit output ->
            Exit output

        NoOp ->
            NoOp


{-| -}
orElse : Step state msg output -> Step state msg output -> Step state msg output
orElse stepA stepB =
    case ( stepA, stepB ) of
        ( To _ _, To state commands ) ->
            To state commands

        ( To state commands, NoOp ) ->
            To state commands

        ( To state commands, Exit output ) ->
            Exit output

        ( NoOp, To state commands ) ->
            To state commands

        ( NoOp, NoOp ) ->
            NoOp

        ( NoOp, Exit output ) ->
            Exit output

        ( Exit output, To state commands ) ->
            Exit output

        ( Exit output, NoOp ) ->
            Exit output

        ( Exit _, Exit output ) ->
            Exit output


{-| -}
exit : output -> Step state msg output
exit =
    Exit


{-| -}
mapExit : (o -> p) -> Step state msg o -> Step state msg p
mapExit f step =
    case step of
        To state commands ->
            To state commands

        Exit output ->
            Exit (f output)

        NoOp ->
            NoOp


{-| -}
onExit : (o -> Step state msg p) -> Step state msg o -> Step state msg p
onExit f step =
    case step of
        To state commands ->
            To state commands

        Exit output ->
            f output

        NoOp ->
            NoOp


{-| asUpdateFunction

a little helper function for the common case: turn an update function that returns a `Step` to a normal elm architecture update function
uses `run` internally to default with the provided model in case of a `noop`

-}
asUpdateFunction : (msg -> model -> Step model msg Never) -> msg -> model -> ( model, Cmd msg )
asUpdateFunction update msg model =
    update msg model
        |> run
        |> Maybe.withDefault ( model, Cmd.none )


{-| -}
run : Step state msg Never -> Maybe ( state, Cmd msg )
run s =
    case s of
        To state commands ->
            Just ( state, Cmd.batch commands )

        Exit n ->
            never n

        NoOp ->
            Nothing


filterMap : (a -> Maybe b) -> Step a msg o -> Step b msg o
filterMap f step =
    case step of
        To state cmds ->
            case f state of
                Just newState ->
                    To newState cmds

                Nothing ->
                    NoOp

        NoOp ->
            NoOp

        Exit o ->
            Exit o


fromMaybe : Maybe a -> Step a msg o
fromMaybe x =
    case x of
        Just s ->
            To s []

        Nothing ->
            NoOp


fromUpdate : ( state, Cmd msg ) -> Step state msg output
fromUpdate ( s, cmd ) =
    To s [ cmd ]



-- foo
--     |> Step.withAttempt someFunc task


withAttempt : (Result x a -> msg) -> Task.Task x a -> Step state msg output -> Step state msg output
withAttempt handler task step =
    case step of
        To state cmds ->
            To state (Task.attempt handler task :: cmds)

        NoOp ->
            NoOp

        Exit o ->
            Exit o


{-| starting from an initial state, fold an update function over a list of messages
-}
foldSteps :
    (msg -> model -> Step model msg output)
    -> Step model msg output
    -> List msg
    -> Step model msg output
foldSteps update init msgs =
    List.foldl (andThen << update) init msgs


andThen : (model1 -> Step model2 msg output) -> Step model1 msg output -> Step model2 msg output
andThen f s =
    case s of
        To state commands ->
            f state |> withCmd (Cmd.batch commands)

        NoOp ->
            NoOp

        Exit output ->
            Exit output
