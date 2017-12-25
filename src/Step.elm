module Step
    exposing
        ( Step
        , to
        , noop
        , withAction
        , withActions
        , map
        , mapMsg
        , orElse
        , runStep
        , finish
        , feed
        )

{-| Some stuff

@docs Step, map, noop, orElse, runStep, to, withAction, withActions, mapMsg, finish, feed

-}


{-| Step
-}
type Step state msg output
    = To state (Cmd msg)
    | Done output
    | NoOp


{-| step to a state with no actions
-}
to : state -> Step state msg output
to state =
    To state Cmd.none


{-| Step multiple machines embedded in a parent state

type Model
= DoingMultipleThings ThingOne.Model ThingTwo.Model

Step.to DoingMultipleThings
|> Step.with (updateFirstThing thing1Msg thing1 )
|> Step.with (updateSecondThing thing2Msg thing2)

-}
with : Step subState msg output -> Step (subState -> state) msg output -> Step state msg output
with step stepF =
    case ( step, stepF ) of
        ( To subState actions, To f actions2 ) ->
            To (f subState) (Cmd.batch [ actions, actions2 ])

        _ ->
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

        Done output ->
            Done output

        NoOp ->
            NoOp


{-| -}
withActions : List (Cmd msg) -> Step state msg output -> Step state msg output
withActions actions step =
    case step of
        To state oldActions ->
            To state (Cmd.batch (oldActions :: actions))

        Done output ->
            Done output

        NoOp ->
            NoOp


{-| -}
map : (subState -> state) -> Step subState msg output -> Step state msg output
map f step =
    case step of
        To state cmd ->
            To (f state) cmd

        Done output ->
            Done output

        NoOp ->
            NoOp


{-| -}
mapMsg : (subMsg -> msg) -> Step state subMsg output -> Step state msg output
mapMsg f step =
    case step of
        To state msgCmd ->
            To state (Cmd.map f msgCmd)

        Done output ->
            Done output

        NoOp ->
            NoOp


{-| -}
finish : output -> Step state msg output
finish =
    Done


{-| -}
orElse : Step state msg output -> Step state msg output -> Step state msg output
orElse stepA stepB =
    case ( stepA, stepB ) of
        ( To _ _, To state actions ) ->
            To state actions

        ( To state actions, NoOp ) ->
            To state actions

        ( To state actions, Done output ) ->
            Done output

        ( NoOp, To state actions ) ->
            To state actions

        ( NoOp, NoOp ) ->
            NoOp

        ( NoOp, Done output ) ->
            Done output

        ( Done output, To state actions ) ->
            Done output

        ( Done output, NoOp ) ->
            Done output

        ( Done _, Done output ) ->
            Done output


{-| -}
feed : (output -> Step state msg output2) -> Step state msg output -> Step state msg output2
feed f step =
    case step of
        To state msgCmd ->
            To state msgCmd

        Done output ->
            f output

        NoOp ->
            NoOp


{-| -}
runStep : Step state msg Never -> Maybe ( state, Cmd msg )
runStep step =
    case step of
        To state msgCmd ->
            Just ( state, msgCmd )

        Done n ->
            never n

        NoOp ->
            Nothing
