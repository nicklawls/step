# step
An experimental library for update functions

`Step s msg o` is inteneded to be the return value of an update function. It encodes a bunch of common update function patterns, uniting them under a simple mental model, that aims to both clean up code and make gluing isolated update functions together easier.


## A mental model for update functions

A `Step s msg o` describes one step of an interaction. Here's a few things about the interactions we're talking about her

  - Interactions can involve the end user of your app, external servers, javascript: anything you might need to coordinate with in an Elm app
  - Interactions can be in one of a finite set of _states_. The states are represented by the type `s`
  - Interactions change state in response to _messages_, actions from the outside world. The messages are represented by the type `msg`
  - When responding to a message, the state of the interaction might change, and `Cmd`s may be fired, potentially producing more messages.
  - Interactions might go on indefinitely, or end. If they end, they result in a final value of type `o`. This might seem a little weird, but it has some nice properties

## Install

```
elm package install xilnocas/step
```
