module Step
    exposing
        ( Step
        , to
        , noop
        , withAction
        , withActions
        , inState
        , withMsg
        , orElse
        , resolve
        )


type Step state msg
    = To state (Cmd msg)
    | NoOp


to : state -> Step state msg
to s =
    To s Cmd.none



{-
   Step.to DoingMultipleThings
       |> Step.with (updateFirstThing thing1Msg thing1 )
       |> Step.with (updateSecondThing thing2Msg thing2)

-}


with : Step subState msg -> Step (subState -> state) msg -> Step state msg
with step stepF =
    case ( step, stepF ) of
        ( To subState actions, To f actions2 ) ->
            To (f subState) (Cmd.batch [ actions, actions2 ])

        _ ->
            NoOp


noop : Step state msg
noop =
    NoOp


withAction : Cmd msg -> Step state msg -> Step state msg
withAction action step =
    case step of
        To state actions ->
            To state (Cmd.batch [ action, actions ])

        NoOp ->
            NoOp


withActions : List (Cmd msg) -> Step state msg -> Step state msg
withActions actions step =
    case step of
        To state oldActions ->
            To state (Cmd.batch (oldActions :: actions))

        NoOp ->
            NoOp


inState : (subState -> state) -> Step subState msg -> Step state msg
inState f step =
    case step of
        To s cmd ->
            To (f s) cmd

        NoOp ->
            NoOp


withMsg : (subMsg -> msg) -> Step state subMsg -> Step state msg
withMsg f step =
    case step of
        To state msgCmd ->
            To state (Cmd.map f msgCmd)

        NoOp ->
            NoOp


orElse : Step state msg -> Step state msg -> Step state msg
orElse stepA stepB =
    case ( stepA, stepB ) of
        ( To s1 actions1, To s2 actions2 ) ->
            To s2 actions2

        ( To s a, NoOp ) ->
            To s a

        ( NoOp, x ) ->
            x


resolve : Step state msg -> Maybe ( state, Cmd msg )
resolve step =
    case step of
        To state msgCmd ->
            Just ( state, msgCmd )

        NoOp ->
            Nothing
