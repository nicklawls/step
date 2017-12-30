module RemoteOp exposing (Model, State(..))

import Html exposing (Html, form)
import Step exposing (Step)
import Task exposing (Task)


type Model prompt
    = Model (State prompt)


type State prompt
    = Prompting prompt
    | Loading


init : prompt -> Step (Model prompt) msg output
init prompt =
    Step.to (Model (Prompting prompt))


type Msg promptingMsg error response
    = OpResult (Result error response)
    | PromptingMsg promptingMsg
    | Cancel



{- Adds cancelation and loading to a state machine that models a form and
   exits with the task that submits the form
-}


update :
    (msg -> state -> Step state msg (Task err res))
    -> Msg msg err res
    -> Model state
    -> Step (Model state) (Msg msg err res) (Maybe (Result err res))
update stepForm msg (Model state) =
    Step.map Model <|
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

            ( PromptingMsg pmsg, Prompting formState ) ->
                stepForm pmsg formState
                    |> Step.map Prompting
                    |> Step.mapMsg PromptingMsg
                    |> Step.onExit
                        (\task ->
                            Step.to Loading
                                |> Step.withAction (Task.attempt OpResult task)
                        )


view : Model form -> ((formMsg -> Msg formMsg e a) -> { cancel : Msg formMsg e a } -> State form -> Html msg) -> Html msg
view (Model state) f =
    f PromptingMsg { cancel = Cancel } state


type Form
    = Valid String
    | Invalid String


type FormMsg
    = TypeString String
    | Confirm


type App
    = GettingString (Model Form)
    | DoingOtherThing
    | Errored
    | GotIt Bool


type Message
    = GettingStringMsg (Msg FormMsg String Bool)
    | StartForm


stepForm : FormMsg -> Form -> Step Form FormMsg String
stepForm formMsg form =
    case ( formMsg, form ) of
        ( TypeString s, _ ) ->
            if List.member s [ "Set", "of", "valid", "strings" ] then
                Step.to (Valid s)
            else
                Step.to (Invalid s)

        ( Confirm, Valid s ) ->
            Step.exit s

        ( Confirm, Invalid _ ) ->
            Step.noop


fetchBool : String -> Task x Bool
fetchBool =
    Debug.crash ""


(>>>) : (a -> b -> c) -> (c -> d) -> a -> b -> d
(>>>) f g =
    \a b -> g (f a b)


example : Message -> App -> Step App Message Never
example msg model =
    case ( msg, model ) of
        ( GettingStringMsg dtm, GettingString remoteForm ) ->
            update (stepForm >>> Step.mapExit fetchBool) dtm remoteForm
                |> Step.map GettingString
                |> Step.mapMsg GettingStringMsg
                |> Step.onExit
                    (\output ->
                        Step.to <|
                            case output of
                                Just (Ok s) ->
                                    GotIt s

                                Just (Err _) ->
                                    Errored

                                Nothing ->
                                    DoingOtherThing
                    )

        ( StartForm, DoingOtherThing ) ->
            Step.map GettingString (init (Invalid ""))

        ( _, _ ) ->
            Step.noop
