module Step exposing
    ( Step, to, stay, fromUpdate, fromMaybe
    , map, mapActions, within
    , run, asUpdateFunction
    , foldSteps
    , apply, applyf, applys, do, tell
    )

{-|


# Steps and how to make them

@docs Step, to, stay, exit, fromUpdate, fromMaybe


# Issuing commands

@docs withCmd, withAttempt, command, attempt


# Transforming and Composing Steps

All of these functions help you build functions that return steps out of other functions that return steps

@docs map, mapActions, within, mapExit, orElse, onExit


# Getting back to TEA land

@docs run, asUpdateFunction


# Testing update functions

@docs foldSteps

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
type Step state a
    = To state (List a)
    | Stay


{-| Transition to a new state, without executing any commands
-}
to : model -> Step model a
to state =
    To state []


{-| Keep the interaction in the state it was in.

**Note**: This will prevent any commands from being returned

    Step.stay == (Step.stay |> Step.withCmd myHttpCall)

If you want to stay in the same state, but run some commands, use `Step.to` explicitly

    Step.to MySameState |> Step.withCmd myHttpCall

-}
stay : Step model a
stay =
    Stay


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
do : a -> Step model a -> Step model a
do action step =
    case step of
        To state actions ->
            To state (action :: actions)

        Stay ->
            Stay


{-| Apply a function to the state inside a `Step`, if it's there

Most useful for building a `Step` out of another `Step` returned from some other update function you're calling

-}
map : (model1 -> model2) -> Step model1 a -> Step model2 a
map f step =
    case step of
        To state cmd ->
            To (f state) cmd

        Stay ->
            Stay


{-| Turn a `Step` into the usual TEA update tuple

It must be a `Step` that doesn't `exit`. We know it is if the type variable `a` is still lowercase, i.e. not a specifc type, and can thus be chosen to be `Never` when calling this function.

-}
run : Step model (Cmd msg) -> Maybe ( model, Cmd msg )
run s =
    case s of
        To state commands ->
            Just ( state, Cmd.batch commands )

        Stay ->
            Nothing


{-| Turn an update function that returns a `Step` to a normal Elm Architecture update function

uses `run` internally to default with the provided model in case of a `stay`

-}
asUpdateFunction : (msg -> model -> Step model (Cmd msg)) -> msg -> model -> ( model, Cmd msg )
asUpdateFunction update msg model =
    update msg model
        |> run
        |> Maybe.withDefault ( model, Cmd.none )


{-| Step to the state denoted by the `model` in the `Just` case, stay otherwise
-}
fromMaybe : Maybe model -> Step model a
fromMaybe x =
    -- TODO rename
    case x of
        Just s ->
            To s []

        Nothing ->
            Stay


{-| Starting from an initial state, fold an update function over a list of messages

Only use this to test that the application of certain messages produces the result you expect. In application code, building up a bunch of `Msg`s just to feed them to an update function is ususally not worth the effort.

-}
foldSteps :
    (msg -> model -> Step model (Cmd msg))
    -> ( model, Cmd msg )
    -> List msg
    -> Step model (Cmd msg)
foldSteps update init msgs =
    {- TODO rename -}
    List.foldl (andThen << update) (fromUpdate init) msgs


fromUpdate =
    Debug.todo ""


andThen : (s -> Step t a) -> Step s a -> Step t a
andThen f s =
    case s of
        To state commands ->
            f state
                |> doMany commands

        Stay ->
            Stay


doMany : List a -> Step s a -> Step s a
doMany actions s =
    case s of
        To state moar ->
            To state (actions ++ moar)

        Stay ->
            Stay


tell : a -> Step s a
tell =
    Debug.todo ""


listen : Step s a -> Step ( s, List a ) Never
listen step =
    case step of
        To state actions ->
            To ( state, actions ) []

        Stay ->
            Stay


pass : Step ( s, List a -> List b ) a -> Step s b
pass step =
    case step of
        To ( state, f ) actions ->
            To state (f actions)

        Stay ->
            Stay


applyf : (a -> Maybe b) -> Step s a -> Step s b
applyf f step =
    step
        |> map (\s -> Tuple.pair s (List.filterMap f))
        |> pass


{-| for each action of type `a`, produce zero or more actions of type `b`
-}
apply : (a -> List b) -> Step s a -> Step s b
apply f step =
    step
        |> map (\s -> Tuple.pair s (List.concatMap f))
        |> pass


applys : (a -> Step s b) -> Step s a -> Step s b
applys f step =
    Debug.todo ""



-- step
--     |> map (\s -> Tuple.pair s (List.concatMap f))
--     |> pass


{-| Use a step "within" a larger interaction

    Step.within f g = Step.map f >> Step.mapActions g

-}
within : (s -> t) -> (a -> b) -> Step s a -> Step t b
within f g =
    map f >> mapActions g


mapActions : (a -> b) -> Step s a -> Step s b
mapActions f s =
    case s of
        To state actions ->
            To state (List.map f actions)

        Stay ->
            Stay


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
when predicate step =
    Debug.todo ""



-- case step of
--     To model msgCmdList ->
--         if predicate model then
--             To model msgCmdList
--
--         else
--             Stay
--
--     Exit a ->
--         Exit a
--
--     Stay ->
--         Stay
