module RemoteOp exposing (Model, Msg, State(..), init, map, update, view)

import Html exposing (Html)
import Step exposing (Step)
import Task exposing (Task)


type Model prompt
    = Model (State prompt)


type State prompt
    = Prompting prompt
    | Loading


map : (a -> b) -> Model a -> Model b
map f (Model state) =
    Model <|
        case state of
            Prompting a ->
                Prompting (f a)

            Loading ->
                Loading


init : prompt -> Step (Model prompt) msg output
init prompt =
    Step.to (Model (Prompting prompt))


type Msg promptingMsg error response
    = OpResult (Result error response)
    | PromptingMsg promptingMsg
    | Cancel
    | Confirm



{- Adds cancelation and loading to a state machine that models a form and
   exits with the task that submits the form
-}


updateWithContext :
    { stepForm : msg -> state -> Step ( context, state ) msg Never
    , onConfirm : state -> Step ( context, state ) msg ( context, Task err res )
    }
    -> Msg msg err res
    -> Model state
    -> Step ( context, Model state ) (Msg msg err res) (Maybe (Result err res))
updateWithContext { stepForm, onConfirm } msg (Model state) =
    Step.map (Tuple.mapSecond Model) <|
        case ( msg, state ) of
            ( OpResult _, Prompting _ ) ->
                Step.noop

            ( OpResult res, Loading ) ->
                Step.exit (Just res)

            ( PromptingMsg _, Loading ) ->
                Step.noop

            ( Cancel, Loading ) ->
                Step.noop

            ( Cancel, Prompting _ ) ->
                Step.exit Nothing

            ( Confirm, Prompting formState ) ->
                onConfirm formState
                    |> Step.map (Tuple.mapSecond Prompting)
                    |> Step.mapMsg PromptingMsg
                    |> Step.onExit
                        (\( context, task ) ->
                            Step.to ( context, Loading )
                                |> Step.withCmd (Task.attempt OpResult task)
                        )

            ( Confirm, Loading ) ->
                Step.noop

            ( PromptingMsg pmsg, Prompting formState ) ->
                stepForm pmsg formState
                    |> Step.map (Tuple.mapSecond Prompting)
                    |> Step.mapMsg PromptingMsg
                    |> Step.mapExit never


update :
    { stepForm : msg -> state -> Step state msg Never
    , onConfirm : state -> Step state msg (Task err res)
    }
    -> Msg msg err res
    -> Model state
    -> Step (Model state) (Msg msg err res) (Maybe (Result err res))
update { stepForm, onConfirm } msg model =
    Step.map Tuple.second <|
        updateWithContext
            { stepForm = \msg state -> Step.map withUnit (stepForm msg state)
            , onConfirm = onConfirm >> Step.mapExit withUnit >> Step.map withUnit
            }
            msg
            model


withUnit : a -> ( (), a )
withUnit a =
    ( (), a )


view :
    Model form
    ->
        ((formMsg -> Msg formMsg e a)
         ->
            { cancel : Msg formMsg e a
            , confirm : Msg formMsg e a
            }
         -> State form
         -> Html msg
        )
    -> Html msg
view (Model state) f =
    f PromptingMsg { cancel = Cancel, confirm = Confirm } state
