module RemoteOp exposing (..)

import Step exposing (Step)
import Task exposing (Task)


type RemoteOp prompt
    = Prompting prompt
    | Loading


init : prompt -> RemoteOp prompt
init =
    Prompting


type Msg error response
    = Answer (Result error response)
    | Confirm
    | Cancel


type alias Config prompt err res =
    { makeRequest : prompt -> Task err res }


update :
    Msg err res
    -> RemoteOp prompt
    -> Config prompt err res
    -> Step (RemoteOp prompt) (Msg err res) (Maybe (Result err res))
update msg remoteOp config =
    case ( msg, remoteOp ) of
        ( Confirm, Prompting prompt ) ->
            Step.to Loading
                |> Step.withAction
                    (config.makeRequest prompt
                        |> Task.attempt Answer
                    )

        ( Confirm, Loading ) ->
            Step.noop

        ( Cancel, Prompting _ ) ->
            Step.finish Nothing

        ( Cancel, Loading ) ->
            Step.noop

        ( Answer res, Loading ) ->
            Step.finish (Just res)

        ( Answer res, Prompting _ ) ->
            Step.noop


type Model
    = DoingThing (RemoteOp ())
    | DoingOtherThing
    | Errored
    | GotIt Bool


type Message
    = Rom (Msg String Bool)


example : Message -> Model -> Step Model Message Never
example msg model =
    case ( msg, model ) of
        ( Rom romsg, DoingThing remoteOp ) ->
            { makeRequest = \() -> Task.succeed True }
                |> update romsg remoteOp
                |> Step.map DoingThing
                |> Step.mapMsg Rom
                |> Step.feed
                    (Maybe.map (Result.map GotIt >> Result.withDefault Errored)
                        >> Maybe.withDefault DoingOtherThing
                        >> Step.to
                    )

        ( _, _ ) ->
            Step.noop
