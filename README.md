# Pin

An experimental package for clean update functions forked from [xilnocas/step](https://github.com/xilnocas/step)

## Overview

Becuase updating (`Pin.g`'ing) your content (AKA: Model) should be like sending (`Pin.send`) and receiving (`pong`) `Notes from to content`? 

Code that used to look like this:

```elm
let
    (newLogin, loginCmd) =
        Login.update loginMsg model.page -- where page is a Sum type of different child models...
in
    ({ model | login = newLogin }, Cmd.map LoginMsg loginCmd)
```

will come out looking like this

```elm
Login.update loginMsg loginModel
    |> Pin.wrap LoginMsg LoginModel
    |> Pin.edit (\w -> { model | page = w })
```

Instead of returning a `(Model, Cmd Msg)` from your update function, you'll return a `Note from ToChildMsg ChildContent`, where the `from` variable is used for a child to communicate back up to the parent. I know, I know, there are _three_ type variables there. In return for having to look at three freakin type variables all day long, you'll get the above cleanliness improvement and a bunch of other goodies.


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
Pin.write newModel : Note from to Model
```

Before, if you wanted to fire off a command in addition to updating state, you'd do so like this:

```elm
( newModel
, Http.send ServerResponse (Http.get "/fruits" fruitDecoder)
)
```

With `Pin`, it looks like this:


```elm
let
    note =
        Pin.write model
in
note
    |> Pin.g (Http.send ServerResponse (Http.get "fruits.json" fruitDecoder))
```

If you're a veteran, think of it like the old `model ! []` syntax except you can chain your `Cmd msgs` with `|>`

### Calling nested update functions

Code that looks like this

```elm
update : Msg -> Model -> (Model , Cmd Msg)
update msg ({key, page} as content) =
    case (msg, page) of
        (LoginMsg loginMsg, Login loginModel) ->
            let
                (newLogin, loginCmd) =
                    Login.update loginMsg loginModel

            in
                ({ model | page = newLogin }, Cmd.map LoginMsg loginCmd)                    
```

turns into this

```elm
import Step exposing (Step)

update : Msg -> Model -> Note from Msg Model
update msg ({key, page} as content) =
    case (msg, page) of
        (LoginMsg loginMsg, Login loginModel) ->
            Login.update loginMsg loginModel
                |> Pin.wrap LoginMsg Login
                |> Pin.edit (\w -> { model | page = w })

```

The idea behind the name `wrap` is that you're `wrap`ing a `Note` in some child `update` with the parent `Note` constructors.


### Handling invalid transitions

`Pin.wait` is sort of like `Nothing`, but specialized for `Note`s. It lets you say "on this combination of `Model` and `Msg`, I don't want the state to transition." Basically, any time you want to say

```elm
(model, Cmd.none)
```

just say

```elm
Pin.point -- the () Unit or Golden Thread of a Note. Not Never, void, or empty but just what it is.
```

And this isn't just a terser syntax. `Step.orElse` lets you combine a bunch of isolated steps, and return only the first one that isn't a `point`

```elm
let
  stepCalendar =
      case msg of
          AddEvent e ->
              Step.to { model | calendar = e :: model.calendar }

          _ ->
              Step.point

  stepContacts =
      case msg of
          AddContact c ->
              Step.to { model | contacts = c :: model.contacts }

          _ ->
              Step.point

in
  stepCalendar
      |> Step.orElse stepContacts
      -- if msg is AddContact, will return value of stepContacts
```

This can be handy as you're iterating on an app, where you know roughly which pieces of state are isolated from one another, but you don't want to split messages up into their own types quite yet.


### Returning extra data from `update`

Often when splitting an app into a set of distinct update functions, some of those update functions are involved in producing a value other than the state that the calling update function needs to consume.


As an example, think of a login interaction: It starts, proceeds as the user types their info, then some REST call is made on submit, then when all is said and done we're left with a `User`. We can encode that idea really easily with `pong`


```elm
module Login exposing (..)


update : Msg -> Model -> Note User Msg Model
update msg model =
    case msg of

      -- Usual filling out of a login form ...

       LoginSucceeded user ->
          pong user

```

Here we see the third type variable come into play. It represents the type of data that eventually gets returned in the final `Note` of the interaction we're modeling.

Now, whoever uses our `Login` module can use `Pin.pong` or just `pong` to incorporate this data into their own `Note` with the `Pin.pongWith` or just `pongWith` function.

```elm
module Main exposing (..)

import Login


update : Msg -> Model -> Note a Msg Model
update msg model =
    case (msg, model) of
        (LoginMsg loginMsg, LoggingIn loginModel) ->
            Login.update loginMsg loginModel
                |> Pin.wrap LoginMsg LoggingIn
                |> Pin.onPong (\user -> Pin.write (LoggedIn user))
```

Elm veterans might notice that this bears some resemblance to the "OutMsg" pattern. I think calling it that is more confusing than helpful. It's not a "Msg" (in the elm sense) that's coming back per se, it's just a normal elm value that you can use how you please.

And, crucially, we're restricting ourselves to interactions in which returning a value of type `a` is the _last thing that happens_, in some sense. This ensures we're not creating some tightly coupled conversation between two pieces of state, a-la OOP.

My experience is that building modules around these sorts of `exit` boundaries ultimately leads to easier to understand code. I'm excited to see if the community finds this to be true as well!


### Wiring it up

You can use `Pin` at any point in an app. But at some point, you're going to have to convert `Notes`s back into the `(model, Cmd msg)` that The Elm Architecture demands. The easiest way to do this is with `Pin.tack`. Just pass it an update function defined with `Note`, and it'll spit out a TEA-compatible update function that does what you'd expect.

We also provide `Pin.run` if you want more control over happens when the result is just a `Note` value.

There is some subtle type trickery going on in these functions with the `Never` type. All you should have to know is that in order to pass something to `run` or `tack`, the first type variable in the `Note` (named `from` in the docs) can't be filled in with a concrete type. If it is, you need to call `onPong` on it and consume the return value in some way to get the types to line up.


## Example app

To provide an orienting example, I've [forked Richard's `elm-spa-example`](https://github.com/xilnocas/elm-spa-example), and converted all the update functions to return `Notes`s. It so happens that that app is architected in a way that makes `Note` less useful; there were no opportunities to use `orElse` or `onPong`. Still, looking at the diff will give you an idea of how things translate.


## FAQ

Under Construction

## Prior Work

The idea for this kind of package is not new. `Note` wouldn't be a thing without inspiration from the following libraries

### [Fresheyeball/elm-return](https://package.elm-lang.org/packages/Fresheyeball/elm-return/latest)

* My original inspiration for this sort of package. The pattern of appending commands with a pipeline-friendly function really appealed to me
* Over-relies on Haskelley lingo
* Too much API. As an example, `Pin` doesn't have an `andThen` function exposed, because I've never had a use for one.

### [Janiczek/cmd-extra](https://package.elm-lang.org/packages/Janiczek/cmd-extra/latest/)

* Pleasingly simple
* Too little API!

### [Chadtech/return](https://package.elm-lang.org/packages/Chadtech/return/latest/)

* A `Return3` is the closest thing to a `Note` I've seen. The `incorp` function is very similar in purpose to the `onPong` function, and seeing it helped me realize I was on the right track.

* `Return3` lets you return state, commands, and extra stuff all at the same time, which I suspect is unnecessary. The idea of an interaction's behavior being constantly dependent on data from a sub-interaction makes me think that the two should probably be folded into one. In contrast, `Note` optimizes for when there's a clean break between the two.

* I struggle to form a mental model for what a `Return3` is. It's a name for the code pattern, whereas `Note` tries to be a name for a higher-level entity: a step in TEA's update loop.


## Installation

```
elm install erlandsona/pin
```
