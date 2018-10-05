module Step exposing
    ( Step, to, stay, exit, fromUpdate, fromMaybe
    , withCmd, withAttempt, command, attempt
    , map, mapMsg, within, mapExit, onExit
    , run, asUpdateFunction
    , replay
    )

{-|


# Steps and how to make them

@docs Step, to, stay, exit, fromUpdate, fromMaybe


# Issuing commands

@docs withCmd, withAttempt, command, attempt


# Transforming and Composing Steps

All of these functions help you build functions that return steps out of other functions that return steps

@docs map, mapMsg, within, mapExit, onExit


# Getting back to TEA land

@docs run, asUpdateFunction


# Testing update functions

@docs replay

-}

import Task


{-| A `Step model msg a` describes one state transition of an application, and is intended to be what gets returned from an update function.

It's helpful to look at how a `Step` is (roughly) represented under the hood

    type Step model msg a
        = To model (Cmd msg)
        | Exit a
        | Stay

We provide a smart constructor for each of these variants, but we hide the internal representation to make sure you're not pattern matching on `Step`s willy-nilly.

That being said, if you find something that makes you want the data structure fully exposed, please make an issue on GitHub!

-}
type Step model msg a
    = To model (List (Cmd msg))
    | Stay (List (Cmd msg))
    | Exit a


{-| Transition to a new state, without executing any commands
-}
to : model -> Step model msg a
to state =
    To state []


{-| Keep the interaction in the state it was in.

**Note**: This will prevent any commands from being returned

    Step.stay == (Step.stay |> Step.withCmd myHttpCall)

If you want to stay in the same state, but run some commands, use `Step.to` explicitly

    Step.to MySameState |> Step.withCmd myHttpCall

-}
stay : Step model msg a
stay =
    Stay []


{-| End the interaction by returning a value of type `a`
-}
exit : a -> Step model msg a
exit =
    Exit


{-| If we're stepping `to` a new state, add an cmd to fire off

This can be called on a `Step` multiple times, and all the commands will fire.

No commands are fired if the Step turns out to be a `stay` or an `exit`

Alternate name ideas:

  - effectfully
  - cmd
  - command (provided below)
  - yelling
  - with

-}
withCmd : Cmd msg -> Step model msg a -> Step model msg a
withCmd cmd step =
    case step of
        To state commands ->
            To state (cmd :: commands)

        Exit o ->
            Exit o

        Stay commands ->
            Stay commands


{-| Experimental alias for withCmd
-}
command : Cmd msg -> Step model msg a -> Step model msg a
command cmd step =
    case step of
        To state commands ->
            To state (cmd :: commands)

        Exit o ->
            Exit o

        Stay commands ->
            Stay (cmd :: commands)


{-| Apply a function to the state inside a `Step`, if it's there

Most useful for building a `Step` out of another `Step` returned from some other update function you're calling

-}
map : (model1 -> model2) -> Step model1 msg a -> Step model2 msg a
map f step =
    case step of
        To state cmd ->
            To (f state) cmd

        Exit o ->
            Exit o

        Stay cmd ->
            Stay cmd


{-| Apply a function to any `msg`s in the `Step`'s commands

Often used alongside `map` for building "bigger" `Step`s out of "smaller" ones

-}
mapMsg : (msg1 -> msg2) -> Step model msg1 a -> Step model msg2 a
mapMsg f step =
    case step of
        To state msgCmd ->
            To state (List.map (Cmd.map f) msgCmd)

        Exit o ->
            Exit o

        Stay cmds ->
            Stay (List.map (Cmd.map f) cmds)


{-| Map over the output of an interaction, if we've reached the end
-}
mapExit : (a -> b) -> Step model msg a -> Step model msg b
mapExit f step =
    case step of
        To state commands ->
            To state commands

        Exit o ->
            Exit (f o)

        Stay cmds ->
            Stay cmds


{-| Choose a `Step` based on the result of another interaction

You can use this in combination with `map` and `mapMsg` to glue the end of one interaction to the beginning of another.

Notice that it looks a lot like `Maybe.andThen` and `Result.andThen`, but operating on the last type variable.

-}
onExit : (a -> Step model msg b) -> Step model msg a -> Step model msg b
onExit f step =
    case step of
        To state commands ->
            To state commands

        Exit o ->
            f o

        Stay cmds ->
            Stay cmds


{-| Turn a `Step` into the usual TEA update tuple

It must be a `Step` that doesn't `exit`. We know it is if the type variable `a` is still lowercase, i.e. not a specifc type, and can thus be chosen to be `Never` when calling this function.

-}
run : Step model msg Never -> ( Maybe model, Cmd msg )
run s =
    case s of
        To state commands ->
            ( Just state, Cmd.batch commands )

        Exit n ->
            never n

        Stay cmds ->
            ( Nothing, Cmd.batch cmds )


{-| Turn an update function that returns a `Step` to a normal Elm Architecture update function

uses `run` internally to default with the provided model in case of a `stay`

-}
asUpdateFunction : (msg -> model -> Step model msg Never) -> msg -> model -> ( model, Cmd msg )
asUpdateFunction update msg model =
    update msg model
        |> run
        |> Tuple.mapFirst (Maybe.withDefault model)


{-| Step to the state denoted by the `model` in the `Just` case, stay otherwise
-}
fromMaybe : Maybe model -> Step model msg a
fromMaybe x =
    -- TODO rename
    case x of
        Just s ->
            To s []

        Nothing ->
            Stay []


{-| Build a `Step` from a normal elm update tuple
-}
fromUpdate : ( model, Cmd msg ) -> Step model msg o
fromUpdate ( s, cmd ) =
    To s [ cmd ]


{-| A helper for building `Step`s out of tasks
-}
withAttempt : (Result x a -> msg) -> Task.Task x a -> Step model msg b -> Step model msg b
withAttempt handler task step =
    case step of
        To state cmds ->
            To state (Task.attempt handler task :: cmds)

        Stay cmds ->
            Stay cmds

        Exit o ->
            Exit o


{-| Experimental alias for `withAttempt`
-}
attempt : (Result x a -> msg) -> Task.Task x a -> Step model msg b -> Step model msg b
attempt handler task step =
    case step of
        To state cmds ->
            To state (Task.attempt handler task :: cmds)

        Stay cmds ->
            Stay cmds

        Exit o ->
            Exit o


{-| Starting from an initial state, fold an update function over a list of messages

This function is intended as a convenience for testing update functions.

In application code, building up a bunch of `Msg`s just to feed them to an `update` function can make code hard to follow. Instead, consider refactoring the code from the `update` branches into helper functions, and calling them in multiple places.

-}
replay :
    (msg -> model -> Step model msg a)
    -> ( model, Cmd msg )
    -> List msg
    -> Step model msg a
replay update init history =
    List.foldl (andThen << update) (fromUpdate init) history


andThen : (model1 -> Step model2 msg o) -> Step model1 msg o -> Step model2 msg o
andThen f s =
    case s of
        To state commands ->
            f state |> withCmd (Cmd.batch commands)

        Stay cmds ->
            Stay cmds

        Exit o ->
            Exit o


mapWithCmd : (model1 -> ( model2, Cmd msg )) -> Step model1 msg a -> Step model2 msg a
mapWithCmd f step =
    case step of
        To state commands ->
            let
                ( newState, moarCmds ) =
                    f state
            in
            To newState (moarCmds :: commands)

        Stay cmds ->
            Stay cmds

        Exit a ->
            Exit a


{-| Use a step "within" a larger interaction

    Step.within f g = Step.map f >> Step.mapMsg g

-}
within : (model1 -> model2) -> (msg1 -> msg2) -> Step model1 msg1 a -> Step model2 msg2 a
within f g =
    map f >> mapMsg g


withCmds : List (Cmd msg) -> Step model msg a -> Step model msg a
withCmds a =
    withCmd (Cmd.batch a)


{-| Step to a new state and cmd the

    Step.lead

    Step.to Loading
        |> Step.withCmd httpRequest
        |> Step.cmd httpRequest

    Step.to Loading
        |> Step.cmd httpRequest

    Step.to Loading
        |> Step.cmd httpRequest

    Step.withCmd httpRequest Loading

-}
withCmd_ : Cmd msg -> model -> Step model msg a
withCmd_ cmd model =
    To model [ cmd ]
