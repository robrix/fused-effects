# Overview

`fused-effects` is an [effect system](https://en.wikipedia.org/wiki/Effect_system) for Haskell that values expressivity, efficiency, and rigor. It provides an encoding of [algebraic](#algebraic-effects), [higher-order](#higher-order-effects) effects, includes a library of the most common effects, and generates efficient code by [fusing](#fusion) effect handlers through computations. It is suitable for use in hobbyist, research, and industrial contexts.

Readers already familiar with effect systems may wish to start with the [usage](#usage) instead. For those interested, this [talk at Strange Loop](https://www.youtube.com/watch?v=vfDazZfxlNs) outlines the history of and motivation behind effect systems and `fused-effects` itself.

<!--
Setup, hidden from the rendered markdown.

```haskell
{-# LANGUAGE ConstraintKinds, FlexibleInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, UndecidableInstances #-}
module Main (module Main) where

import Control.Algebra
import Control.Carrier.Lift
import Control.Carrier.Reader
import Control.Carrier.State.Strict
import Control.Monad.IO.Class (liftIO)

main :: IO ()
main = pure ()
```
-->

## Algebraic effects

In `fused-effects` and other systems with _algebraic_ (or, sometimes, _extensible_) effects, effectful programs are split into two parts: the specification (or _syntax_) of the actions to be performed, and the interpretation (or _semantics_) given to them.

In `fused-effects`, _effect types_ provide syntax and _carrier types_ provide semantics. Effect types are datatypes with one constructor for each action, invoked using the `send` builtin. Carriers are monads, with an `Algebra` instance specifying how an effect’s constructors should be interpreted. Carriers can handle more than one effect, and multiple carriers can be defined for the same effect, corresponding to different interpreters for the effect’s syntax.

## Higher-order effects

Unlike some other effect systems, `fused-effects` offers _higher-order_ (or _scoped_) effects in addition to first-order algebraic effects. In a strictly first-order algebraic effect system, operations like `local` or `catchError`, which specify some action limited to a given scope, must be implemented as interpreters, hard-coding their meaning in precisely the manner algebraic effects were designed to avoid. By specifying effects as higher-order functors, this limitation is removed, meaning that these operations admit a variety of interpretations. This means, for example, that you can introspect and redefine both the `local` and `ask` operations provided by the `Reader` effect, rather than solely `ask` (as is the case with certain formulations of algebraic effects).

As Nicolas Wu et al. showed in _[Effect Handlers in Scope][]_, this has implications for the expressiveness of effect systems. It also has the benefit of making effect handling more consistent, since scoped operations are just syntax which can be interpreted like any other, and are thus simpler to reason about.

## Fusion

In order to maximize efficiency, `fused-effects` applies _fusion laws_, avoiding the construction of intermediate representations of effectful computations between effect handlers. In fact, this is applied as far as the initial construction as well: there is no representation of the computation as a free monad parameterized by some syntax type. As such, `fused-effects` avoids the overhead associated with constructing and evaluating any underlying free or freer monad.

Instead, computations are performed in a carrier type for the syntax, typically a monad wrapping further monads, via an instance of the `Carrier` class. This carrier is specific to the effect handler selected, but since it isn’t described until the handler is applied, the separation between specification and interpretation is maintained. Computations are written against an abstract effectful signature, and only specialized to some concrete carrier when their effects are interpreted.

Since the interpretation of effects is written as a typeclass instance which `ghc` is eager to inline, performance is excellent: approximately on par with `mtl`.

Finally, since the fusion of carrier algebras occurs as a result of the selection of the carriers, it doesn’t depend on complex `RULES` pragmas, making it easy to reason about and tune.
