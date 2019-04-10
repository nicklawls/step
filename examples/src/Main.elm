module Main exposing (main)

import Html exposing (Html)
import Step exposing (Step)


type alias Model =
    { guys : Result String (List Int)
    , focus : Result String (List Bool)
    , shit : Result String { shit : () }
    , loading : Bool
    , state : State
    }


type State
    = Home
    | Shitting ShitState


type Msg
    = GotShit (Result String { shit : () })
    | YesGuys (Result String (List Int))
    | NewFocus (Result String (List Bool))
    | ShitMsg ShitMsg


type Action
    = FetchShit String
    | FetchGuys Bool Bool
    | FocusOn { before : Int, after : Int }


type ShitMsg
    = TypeShit String
    | ConfirmShit
    | CancelShit


type ShitState
    = ShitState String


stepShit : ShitMsg -> ShitState -> Step ShitState (Maybe String)
stepShit shitMsg (ShitState state) =
    Step.map ShitState <|
        case shitMsg of
            TypeShit s ->
                Step.to s

            ConfirmShit ->
                Step.tell (Just state)

            CancelShit ->
                Step.tell Nothing


update : Msg -> Model -> Step Model Action
update msg model =
    case ( msg, model.state ) of
        ( ShitMsg shitMsg, Shitting shitState ) ->
            stepShit shitMsg shitState
                |> Step.map (\ss -> { model | state = Shitting shitState })
                |> Step.applys
                    (\maybeShit ->
                        case maybeShit of
                            Just str ->
                                Step.to { model | loading = True }
                                    |> Step.do (FetchShit str)

                            Nothing ->
                                Step.to { model | state = Home }
                    )

        _ ->
            Step.stay


main : Html msg
main =
    Debug.todo ""
