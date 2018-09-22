# step

An experimental package for clean update functions

## Overview

Use this package to write update functions in your Elm app.

Instead of returning a `(Model, Cmd Msg)` from your update function, you'll return a `Step Model Msg a`, with or without the `a` variable filled in. I know, I know, there are _three_ type variables there. In return for having to look at three freakin type variables all day long, code that looks like this:

```elm
let
    (newLogin, loginCmd) =
        Login.update loginMsg model.login
in
    ({ model | login = newLogin }, Cmd.map LoginMsg loginCmd)
```

will come out looking like this

```elm
Login.update loginMsg model.login
    |> Step.within (\w -> { model | login = w }) LoginMsg
```

And that's just the beginning.

The goal is that by using `step`, you'll be able to

1. Express common update function patterns easily and safely
1. Think and talk about these patterns in a way that makes sense with TEA
1. Notice more easily how many states your app has, helping you "make impossible states impossible"


## Usage

Here's a quick tour of some important features


### Returning state, maybe with commands

A lot of the time, all your update function does is update the state of the app. You usually return something like this


```elm
(newModel, Cmd.none)
```

With `step`, you'll return this

```elm
Step.to newModel
```

If you want to fire off a command in addition to the state change, you'd do so like this.

```elm
( newModel
, Http.send ServerResponse (Http.get "/fruits" fruitDecoder)
)
```

With `step`, it looks like this


```elm
Step.to newModel
    |> Step.command (Http.send ServerResponse (Http.get "fruits.json" fruitDecoder))
```


### Calling nested update functions

Code that looks like this

```elm
update : Msg -> Model -> (Model , Cmd Msg)
update msg model =
    case msg of
        LoginMsg loginMsg ->
            let
                (newLogin, loginCmd) =
                    Login.update loginMsg model.login

            in
                ({ model | login = newLogin }, Cmd.map LoginMsg loginCmd)                    
```

turns into this

```elm
import Step exposing (Step)

update : Msg -> Model -> Step Model Msg a
update msg model =
    case msg of
        LoginMsg loginMsg ->
            Login.update loginMsg model.login
                |> Step.within (\w -> { model | login = w }) LoginMsg

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

But this isn't just terser syntax. `Step.orElse` lets you combine a bunch of isolated steps, and return only the first one that isn't a `stay`

```elm
let
  stepCalendar =
      case msg of
          AddEvent e ->
              Step.to { model | calendar = e :: model.calendar }

          _ ->
              Step.stay

  stepContacts =
      case msg of
          AddContact c ->
              Step.to { model | contacts = c :: model.contacts }

          _ ->
              Step.stay

in
  stepCalendar
      |> Step.orElse stepContacts
      -- if msg is AddContact, will return value of stepContacts
```

This can be super useful as you're iterating on an app, where you know roughly which pieces of state are isolated from one another, but you don't want to split messages up into their own types quite yet.


### Returning extra data from `update`

`Step.exit` and `Step.onExit` work together to implement a version of what's sometimes called the "OutMsg" pattern, which is really just returning context other than the `(Model, Cmd Msg)` from an update function.

A special case of that pattern that I've found really useful is when *the context only comes out when update function makes its final transition*.

As an example, think of a login interaction: It starts, proceeds as the user types their info, then some REST call is made, then when all is said and done we're left with a `User`. We can encode that idea really easily


```elm
module Login exposing (..)


update : Msg -> Model -> Step Model Msg User
update msg model =
    case msg of

      -- Usual filling out of a login form ...

       LoginSucceeded user ->
          Step.exit user

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


## Example app

To provide an orienting example, I've [forked Richard's `elm-spa-example`](https://github.com/xilnocas/elm-spa-example), and converted all the update functions to return `Steps`. It so happens that that app is architected in a way that makes `step` less useful; there were no opportunities to use `orElse` or `onExit`. Still, looking at the diff will give you an idea of how things translate.

## Prior Work

The idea for this kind of package is not new. `Step` wouldn't be a thing without inspiration from the following libraries

### [Fresheyeball/elm-return](https://package.elm-lang.org/packages/Fresheyeball/elm-return/latest)

* My original inspiration for this sort of package. The pattern of appending commands with a pipeline-friendly function really appealed to me
* Over-relies on Haskelley lingo
* Too much API. As an example, `Step` doesn't have an `andThen` function exposed, because I've never had a use for one.

### [Janiczek/cmd-extra](https://package.elm-lang.org/packages/Janiczek/cmd-extra/latest/)

* Pleasingly simple
* Too little API ( :) )

### [Chadtech/return](https://package.elm-lang.org/packages/Chadtech/return/latest/)

* A `Return3` is the closest thing to a `Step` I've seen. The `incorp` function is very similar in purpose to the `onExit` function, and seeing it helped me realize I was on the right track.

* `Return3` lets you return state, commands, and extra stuff all at the same time, which I suspect is unnecessary. The idea of an interaction's behavior being constantly dependent on data from a sub-interaction makes me think that the two should probably be folded into one. In contrast to `Return3`, `Step` optimizes for when there's a clean break between the two.

* I struggle to form a mental model for what a `Return3` is. It's a name for the code pattern, whereas `Step` tries to be a name for a higher-level entity: a step in TEA's update loop.


## Installation

```
elm install xilnocas/step
```