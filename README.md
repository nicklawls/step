# step
An experimental library for cleaner, more composable update functions

## Installation

```
elm install xilnocas/step
```

## Usage

This library deals with _state transitions_, a fancy term for the act of updating your application's state. When app steps from one state to another, It's undergone a state transition. In an elm app, state transitions happen in response to messages. The update function is what tells Elm how to transition the state of your app when a particular message occurs.

The idea is that instead of returning a `(Model, Cmd Msg)` from your update function, you return a `Step Model Msg a`, with or without the `a` variable filled in. I know, I know, there are _three_ type variables there. I'd like there to be fewer, but they're just too darn useful! In return for having to look at three freakin type variables all day long, you'll get an API that should look familiar if you've been writing Elm for a while, and lets you encode a bunch of common update function patterns very succinctly.

At least as importantly, I believe the library lets you express these patterns in a way that's less about the visual "components" in your app and more about the _interactions_ underlying them, and helping them have as little state as possible. That way, you can leave all the visual detail for your `view` function, where it belongs!

Here's a quick tour of some important features

### Returning state, issuing commands

TODO

### Less boilerplate calling nested update functions

Code that looks like this

```elm
update : Msg -> Model -> (Model , Cmd Msg)
update msg model =
    case msg of
        WidgetMsg widgetMsg ->
            let
                (newWidget, widgetCmd) =
                    Login.update widgetMsg model.widget

            in
                ({ model | widget = newWidget }, Cmd.map WidgetMsg widgetCmd)                    
```

turns into this

```elm
import Step exposing (Step)

update : Msg -> Model -> Step Model Msg a
update msg model =
    case msg of
        WidgetMsg widgetMsg ->
            Widget.update widgetMsg model.widget
                |> Step.within (\w -> { model | widget = w }) WidgetMsg

```

### Handling invalid transitions

`Step.stay` is sort of like `Nothing`, but specialized for `Step`s. It lets you say "on this combination of `Model` and `Msg`, I don't want the state to transition." Basically, any time you want to say

```elm
(model, Cmd.none)
```

just say

```elm
Step.stay
```

But this isn't just terser syntax. When used in combination with `Step.orElse`, it lets you combine a bunch of isolated steps, and return only the first one that isn't a `stay`

```elm
let
  stepCalendar =
      case msg of
          AddEvent e -> Step.to { model | calendar = e :: model.calendar }

      _ ->
          Step.stay

  stepContacts =
      case msg of
          AddContact c -> Step.to { model | contacts = c :: model.contacts }

      _ ->
          Step.stay

in
  stepCalendar
      |> Step.orElse stepContacts
      -- if msg is AddContact, will return value of stepContacts

```

This can be super useful as you're iterating on an app, where you know roughly which pieces of state are isolated from one another, but you don't want to split messages up into their own types quite yet.


### Returning extra context from `update`

`Step.exit` and `Step.onExit` work together to implement a version of what's sometimes called the "OutMsg" pattern, which is really just returning context other than the `(Model, Cmd Msg)` from an update function. A special case of that pattern that I've found really useful is when *the context only comes out when update function makes its final transition*.

As an example, think of a login interaction: It starts, proceeds as the user types their info, then some REST call is made, then when all is said and done we're left with a `User`. We can encode that idea really easily


```elm
module Login exposing (..)


update : Msg -> Model -> Step Model Msg User
update msg model =
        case msg of
           LoginSucceeded user -> Step.exit user

        ...
```

Then, whoever uses our `Login` module can use `Step.onExit` to incorporate this data into their own `Step`

```elm
module Main exposing (..)

import Login


update : Msg -> Model -> Step Model Msg a
update msg model =
     case (msg, model) of
         (LoginMsg loginMsg, LoggingIn loginModel) ->
            Login.update loginMsg loginModel
                |> Step.within LoggingIn LoginMsg
                |> Step.onExit (\user -> Step.to (LoggedIn user))
         ...
```

My hunch is that this method of building update functions that return data at the end of an interaction covers most of the use cases of the "OutMsg" pattern, and ultimately leads to simpler, easier to understand code. I'm excited so see if the community finds this to be true as well!


## Prior Art

* Fresheyeball/elm-return
    * Original inspiration for this sort of library, appending commands
    * Over-reliance on haskelley lingo
    * Too much API, you don't need most of it

* Janiczek/cmd-extra
    * Too little API

* Chadtech/return
    * a `Return3` is the closest thing to a `Step` I've seen. And the `incorp` function is very close in purpose to the `onExit` function
    * Can return extra stuff + state + commands all at the same time, which I think might be unnecessary or indicate a design smell
    * I struggle to form a mental model for what a `Return3` is. It's a name for a code pattern, whereas `Step` tries to be a name for a higher-level entity: a transition of you application's state.