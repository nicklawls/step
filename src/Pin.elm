module Pin exposing
    ( Note
    , write, g, pong, wait
    , edit, gWith, pongWith, onPong
    , wrap
    , run
    , tack
    , gAttempt
    , foldNotes
    )

{-| import Pin exposing
( Note
, pong
, pongWith
, onPong
)


# Notes and how to make them

@docs Note
@docs write, g, pong, wait


# Transforming and Composing Notes

All of these functions help you build functions that return steps out of other functions that return steps

@docs edit, gWith, pongWith, onPong
@docs wrap, wrapWith


# Getting back to TEA land

@docs run
@docs tack


# In case of you're using a Task???

@docs gAttempt


# Testing update functions

@docs foldNotes

-}

import Task exposing (Task)


{-| A `Note from to content` describes one state transition of an application, and is intended to be what gets returned from an update function.

It's helpful to look at how a `Note` is (roughly) represented under the hood

    type Note from to content
        = Write (List (Cmd to)) content
        | Recieve from
        | Wait

We provide a smart constructor for each of these variants, but we hide the internal representation to make sure you're not pattern matching on `Note`s willy-nilly.

That being said, if you find something that makes you want the data structure fully exposed, please make an issue on GitHub!

-}
type Note from to content
    = Write (List (Cmd to)) content
    | Recieve from
    | Wait


{-| Transition to a new state, without executing any commands
-}
write : content -> Note from to content
write =
    Write []


{-| Stop the interaction by returning a value of type `a`
-}
pong : from -> Note from to content
pong =
    Recieve


{-| Keep the interaction in the state it was in.

**Note**: This will prevent any commands from being returned

    Pin.wait == (Pin.wait |> Pin.gWith myHttpCall)

If you want to empty in the same state, but run some commands, use `Pin.to` explicitly

    Pin.to MySameState |> Note.gWith myHttpCall

-}
wait : Note from to content
wait =
    Wait


{-| If we're stepping `to` a new state, add an cmd to fire off

This can be called on a `Note` multiple times, and all the commands will fire.

No commands are fired if the Note turns out to be a `empty` or an `from`

Alternate name ideas:

  - effectfully
  - cmd
  - command (provided below)
  - yelling
  - with

-}
g : Cmd to -> Note from to content -> Note from to content
g cmd step =
    case step of
        Write commands state ->
            Write (cmd :: commands) state

        Recieve from ->
            Recieve from

        Wait ->
            Wait


{-| Apply a function to the state inside a `Note`, if it's there

Most useful for building a `Note` out of another `Note` returned from some other update function you're calling

-}
edit : (content1 -> content2) -> Note from to content1 -> Note from to content2
edit f step =
    case step of
        Write cmd state ->
            Write cmd (f state)

        Recieve from ->
            Recieve from

        Wait ->
            Wait


{-| Apply a function to any `msg`s in the `Note`'s commands

Often used alongside `map` for building "bigger" `Note`s out of "smaller" ones

-}
gWith : (to1 -> to2) -> Note from to1 content -> Note from to2 content
gWith f step =
    case step of
        Write msgCmd state ->
            Write (List.map (Cmd.map f) msgCmd) state

        Recieve from ->
            Recieve from

        Wait ->
            Wait


{-| Map over the output of an interaction, if we've reached the end
-}
pongWith : (fromA -> fromB) -> Note fromA to content -> Note fromB to content
pongWith fn step =
    case step of
        Write to content ->
            Write to content

        Recieve fromA ->
            Recieve (fn fromA)

        Wait ->
            Wait


{-| Choose a `Note` based on the result of another interaction

You can use this in combination with `map` and `mapMsg` to glue the end of one interaction to the beginning of another.

Notice that it looks a lot like `Maybe.andThen` and `Result.andThen`, but operating on the last type variable.

-}
onPong : (fromA -> Note fromB to content) -> Note fromA to content -> Note fromB to content
onPong f step =
    case step of
        Write to content ->
            Write to content

        Recieve fromA ->
            f fromA

        Wait ->
            Wait


{-| Turn a `Note` into the usual TEA update tuple

It must be a `Note` that doesn't `from`. We know it is if the type variable `a` is still lowercase, i.e. not a specifc type, and can thus be chosen to be `Never` when calling this function.

-}
run : Note Never to content -> Maybe ( content, Cmd to )
run s =
    case s of
        Write commands state ->
            Just ( state, Cmd.batch commands )

        Recieve n ->
            never n

        Wait ->
            Nothing


{-| Turn an update function that returns a `Note` to a normal Elm Architecture update function

uses `run` internally to default with the provided content in case of a `empty`

-}
tack : (to -> content -> Note Never to content) -> to -> content -> ( content, Cmd to )
tack update msg content =
    update msg content
        |> run
        |> Maybe.withDefault ( content, Cmd.none )


{-| A helper for building `Note`s out of tasks
-}
gAttempt : (Result err val -> to) -> Task err val -> Note from to content -> Note from to content
gAttempt handler task step =
    case step of
        Write cmds state ->
            Write (Task.attempt handler task :: cmds) state

        Recieve from ->
            Recieve from

        Wait ->
            Wait


{-| Starting from an initial state, fold an update function over a list of messages

Only use this to test that the application of certain messages produces the result you expect.
In application code, building up a bunch of `Msg`s just to feed them to an update function is ususally not worth the effort.

-}
foldNotes :
    (msg -> content -> Note from to content)
    -> ( content, Cmd to )
    -> List msg
    -> Note from to content
foldNotes update init msgs =
    let
        andThen : (content1 -> Note from to content2) -> Note from to content1 -> Note from to content2
        andThen f s =
            case s of
                Write commands state ->
                    f state |> g (Cmd.batch commands)

                Recieve from ->
                    Recieve from

                Wait ->
                    Wait

        -- Build a `Note` from a normal elm update tuple
        fromUpdate : ( content, Cmd to ) -> Note from to content
        fromUpdate ( content, to ) =
            Write [ to ] content
    in
    {- TODO rename -}
    List.foldl (andThen << update) (fromUpdate init) msgs


{-| Use a step "within" a larger interaction

    Note.within f g = Note.map f >> Note.mapMsg g

-}
wrap : (to1 -> to2) -> (content1 -> content2) -> Note from to1 content1 -> Note from to2 content2
wrap msgConstructor modelConstructor =
    gWith msgConstructor >> edit modelConstructor
