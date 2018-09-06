# elm-state-transition
An experimental library for cleaner, more composable update functions

## Install

```
elm package install xilnocas/elm-state-transition
```

---

This library deals with _state transitions_, a fancy term for the act of updating the state of your application. Any time your app steps from one state to another, It's undergone a state transition. In an elm app, state transitions happen in response to messages. The update function is what tells Elm how to transition the state of your app when a given message fires. So, at the code level, this lbrary deals with writing update functions.

The idea is that instead of returning a `(Model, Cmd Msg)` from your update function, you'll return a `Step Model Msg a`, with or without the `a` variable filled in. I know, I know, there are _three_ type variables there. I'd like there to be fewer, but they're just too darn useful! In return for having to look at three freakin type variables all day long, you'll get an API that should look familiar if you've been doing elm for a while, and lets you encode a bunch of common update function patterns very succinctly. 


At least as importantly importantly, I believe this library expresses these patterns in a way that's less about the visual "components" in your app, and more about _interactions_ that have as little state as possible. That way, you can leave all the visual detail for your `view` function, where it belongs! Here are a few quick examples of what I'm talking about:

* `Step.map` works just like `map` from `Maybe` and `Result`. It lets step a returned from one update function become part of an update function that calls it. If you have update functions with a lot of `let` expressions, you're going to like this function. `Step.mapMsg` works the same way, but for the second type variable.

* `Step.stay` is sort of like `Nothing`, but specialized for `Steps`. It lets you say "on this combination of `Model` and `Msg`, I don't want the state to transition. When used in combination with `Step.orElse`, it lets you combine a bunch of isolated steps, and return only the first one that isn't a `stay`

* `Step.exit` and `Step.onExit` work together to implement a version of what's sometimes called the "OutMsg" pattern, which is really just returning context other than the `(Model, Cmd Msg)` from an update function. A special case of that pattern that I've found really useful is when *the context only comes out when update function makes its final transition*. Think of a login interaction: It starts, proceeds as the user gets types their info, then some REST call is made, then when all is said and done we're left with a `User`. We can encode that idea really easily:


```elm
module Login exposing (..)


update : Msg -> Model -> Step Model Msg User
update msg model = 
        case msg of 
           LoginSucceeded user -> Step.exit user
        
        ...
```

Then, whoever uses our `Login` module can use `Step.onExit` to incorporate this returned data into their own `Step`

```elm
module Main exposing (..)

import Login


update : Msg -> Model -> Step Model Msg a
update msg model = 
     case (msg, model) of 
         (LoginMsg loginMsg, LoggingIn loginModel) -> 
            Login.update loginMsg loginModel
                |> Step.map LoggingIn
                |> Step.mapMsg LoginMsg
                |> Step.onExit (\user ->  Step.to (LoggedIn user) )
         ...
```

My hunch is that this method of building update functions around some piece of data that gets built as the result of a stateful interaction covers most of the use cases of the "OutMsg" pattern, and ulitmately leads to simpler, easier to understand code. I'm excited so see if the community finds this to be true as well!
