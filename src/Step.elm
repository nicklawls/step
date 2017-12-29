module Step
    exposing
        ( Step
        , to
        , noop
        , withAction
        , map
        , mapMsg
        , orElse
        , run
        , exit
        , mapExit
        , onExit
        , andMap
        )

{-| Some stuff

@docs Step, map, noop, orElse, run, to, withAction, mapMsg, exit, mapExit, onExit, andMap

-}


{-| Step

a `Step state msg output` describes one step of a state machine.

On each step, the state machine can either

  - do nothing, a `noop`
  - step `to` some new `state`, potentially executing `Cmd msg`s along the way
  - `exit`, and return a value of type `output`

-}
type Step state msg output
    = To state (Cmd msg)
    | Exit output
    | NoOp


{-| step to a state with no actions
-}
to : state -> Step state msg output
to state =
    To state Cmd.none


{-| Step multiple machines embedded in a parent state

    type Model
        = DoingMultipleThings ThingOne.Model ThingTwo.Model

    nextState =
        Step.to DoingMultipleThings
            |> Step.andMap (updateFirstThing thing1Msg thing1)
            |> Step.andMap (updateSecondThing thing2Msg thing2)

-}
andMap : Step a msg output -> Step (a -> b) msg output -> Step b msg output
andMap step stepF =
    case ( step, stepF ) of
        ( To state actions, To f moreActions ) ->
            To (f state) (Cmd.batch [ actions, moreActions ])

        ( To _ _, Exit output ) ->
            Exit output

        ( To _ _, NoOp ) ->
            NoOp

        ( Exit output, To _ _ ) ->
            Exit output

        ( Exit _, Exit output ) ->
            Exit output

        ( Exit output, NoOp ) ->
            Exit output

        ( NoOp, To _ _ ) ->
            NoOp

        ( NoOp, Exit output ) ->
            Exit output

        ( NoOp, NoOp ) ->
            NoOp


{-| -}
noop : Step state msg output
noop =
    NoOp


{-| -}
withAction : Cmd msg -> Step state msg output -> Step state msg output
withAction action step =
    case step of
        To state actions ->
            To state (Cmd.batch [ action, actions ])

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
            To state (Cmd.map f msgCmd)

        Exit output ->
            Exit output

        NoOp ->
            NoOp


{-| -}
orElse : Step state msg output -> Step state msg output -> Step state msg output
orElse stepA stepB =
    case ( stepA, stepB ) of
        ( To _ _, To state actions ) ->
            To state actions

        ( To state actions, NoOp ) ->
            To state actions

        ( To state actions, Exit output ) ->
            Exit output

        ( NoOp, To state actions ) ->
            To state actions

        ( NoOp, NoOp ) ->
            NoOp

        ( NoOp, Exit output ) ->
            Exit output

        ( Exit output, To state actions ) ->
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
        To state actions ->
            To state actions

        Exit output ->
            Exit (f output)

        NoOp ->
            NoOp


{-| -}
onExit : (o -> Step state msg p) -> Step state msg o -> Step state msg p
onExit f step =
    case step of
        To state msgCmd ->
            To state msgCmd

        Exit output ->
            f output

        NoOp ->
            NoOp


{-| -}
run : Step state msg Never -> Maybe ( state, Cmd msg )
run s =
    case s of
        To state msgCmd ->
            Just ( state, msgCmd )

        Exit n ->
            never n

        NoOp ->
            Nothing
