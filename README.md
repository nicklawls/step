# step

An experimental package for clean update functions

## Overview

Use this package to write update functions in your Elm app.

Code that used to look like this:

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

Instead of returning a `(Model, Cmd Msg)` from your update function, you'll return a `Step Model Msg a`, with or without the `a` variable filled in. I know, I know, there are _three_ type variables there. In return for having to look at three freakin type variables all day long, you'll get the above cleanliness improvement and a bunch of other goodies.


The goal is that by using `step`, you'll be able to

1. Express common update function patterns easily and safely
1. Think and talk about these patterns in a way that makes sense with TEA
1. Notice more easily how many states your app has, helping you "make impossible states impossible"


## Usage

Here's a quick tour of some important features


### Returning state, maybe with commands

A lot of the time, all your update function does is update the state of the app. You usually return something like this:


```elm
(newModel, Cmd.none)
```

With `step`, you'll return this:

```elm
Step.to newModel
```

Before, if you wanted to fire off a command in addition to updating state, you'd do so like this:

```elm
( newModel
, Http.send ServerResponse (Http.get "/fruits" fruitDecoder)
)
```

With `step`, it looks like this:


```elm
Step.to newModel
    |> Step.command
      (Http.send ServerResponse (Http.get "fruits.json" fruitDecoder))
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

The idea behind the name `within` is that you're transforming a step in some smaller interaction to a step `within` some larger interaction.


### Handling invalid transitions

`Step.stay` is sort of like `Nothing`, but specialized for `Step`s. It lets you say "on this combination of `Model` and `Msg`, I don't want the state to transition." Basically, any time you want to say

```elm
(model, Cmd.none)
```

just say

```elm
Step.stay
```

And this isn't just a terser syntax. `Step.orElse` lets you combine a bunch of isolated steps, and return only the first one that isn't a `stay`

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

This can be handy as you're iterating on an app, where you know roughly which pieces of state are isolated from one another, but you don't want to split messages up into their own types quite yet.


### Returning extra data from `update`

Often when splitting an app into a set of distinct update functions, some of those update functions are involved in producing a value other than the state that the calling update function needs to consume.


As an example, think of a login interaction: It starts, proceeds as the user types their info, then some REST call is made on submit, then when all is said and done we're left with a `User`. We can encode that idea really easily with `Step.exit`


```elm
module Login exposing (..)


update : Msg -> Model -> Step Model Msg User
update msg model =
    case msg of

      -- Usual filling out of a login form ...

       LoginSucceeded user ->
          Step.exit user

```

Here we see the third type variable come into play. It represents the type of data that eventually gets returned in the final `Step` of the interaction we're modeling.

Now, whoever uses our `Login` module can use `Step.onExit` to incorporate this data into their own `Step` with the `onExit` function.

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
```

Elm veterans might notice that this bears some resemblance to the "OutMsg" pattern. I think calling it that is more confusing than helpful. It's not a "Msg" (in the elm sense) that's coming back per se, it's just a normal elm value that you can use how you please.

And, crucially, we're restricting ourselves to interactions in which returning a value of type `a` is the _last thing that happens_, in some sense. This ensures we're not creating some tightly coupled conversation between two pieces of state, a-la OOP.

My experience is that building modules around these sorts of `exit` boundaries ultimately leads to easier to understand code. I'm excited to see if the community finds this to be true as well!


### Wiring it up

You can use `step` at any point in an app. But at some point, you're going to have to convert `Step`s back into the `(model, Cmd msg)` that The Elm Architecture demands. The easiest way to do this is with `Step.asUpdateFunction`. Just pass it an update function defined with `Step`, and it'll spit out a TEA-compatible update function that does what you'd expect.

We also provide `Step.run` if you want more control over happens when the `Step` is a `stay`.

There is some subtle type trickery going on in these functions with the `Never` type. All you should have to know is that in order to pass something to `run` or `asUpdateFunction`, the third type variable in the `Step` (named `a` in the docs) can't be filled in with a concrete type. If it is, you need to call `onExit` on it and consume the return value in some way to get the types to line up.


## Example app

To provide an orienting example, I've [forked Richard's `elm-spa-example`](https://github.com/xilnocas/elm-spa-example), and converted all the update functions to return `Step`s. It so happens that that app is architected in a way that makes `step` less useful; there were no opportunities to use `orElse` or `onExit`. Still, looking at the diff will give you an idea of how things translate.


## FAQ

Under Construction

## Prior Work

The idea for this kind of package is not new. `Step` wouldn't be a thing without inspiration from the following libraries

### [Fresheyeball/elm-return](https://package.elm-lang.org/packages/Fresheyeball/elm-return/latest)

* My original inspiration for this sort of package. The pattern of appending commands with a pipeline-friendly function really appealed to me
* Over-relies on Haskelley lingo
* Too much API. As an example, `Step` doesn't have an `andThen` function exposed, because I've never had a use for one.

### [Janiczek/cmd-extra](https://package.elm-lang.org/packages/Janiczek/cmd-extra/latest/)

* Pleasingly simple
* Too little API!

### [Chadtech/return](https://package.elm-lang.org/packages/Chadtech/return/latest/)

* A `Return3` is the closest thing to a `Step` I've seen. The `incorp` function is very similar in purpose to the `onExit` function, and seeing it helped me realize I was on the right track.

* `Return3` lets you return state, commands, and extra stuff all at the same time, which I suspect is unnecessary. The idea of an interaction's behavior being constantly dependent on data from a sub-interaction makes me think that the two should probably be folded into one. In contrast, `Step` optimizes for when there's a clean break between the two.

* I struggle to form a mental model for what a `Return3` is. It's a name for the code pattern, whereas `Step` tries to be a name for a higher-level entity: a step in TEA's update loop.


## Installation

```
elm install xilnocas/step
```