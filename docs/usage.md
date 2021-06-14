# Usage

## Package organization

The `fused-effects` package is organized into two module hierarchies:

- those under `Control.Effect`, which provide effects and functions that invoke these effects’ capabilities.
- those under `Control.Carrier`, which provide carrier types capable of executing the effects described by a given effect type.

An additional module, `Control.Algebra`, provides the `Algebra` interface that carrier types implement to provide an interpretation of a given effect. You shouldn’t need to import it unless you’re defining your own effects.

## Invoking effects

Each module under the `Control.Effect` hierarchy provides a set of functions that invoke effects, each mapping to a constructor of the underlying effect type. These functions are similar to, but more powerful than, those provided by `mtl`. In this example, we invoke the `get` and `put` functions provided by `Control.Effect.State`, first extracting the state and then updating it with a new value:

```haskell
action1 :: Has (State String) sig m => m ()
action1 = get >>= \ s -> put ("hello, " ++ s)
```

The `Has` constraint requires a given effect (here `State`) to be present in a _signature_ (`sig`), and relates that signature to be present in a carrier type (`m`). We generally, but not always, program against an abstract carrier type, usually called `m`, as carrier types always implement the `Monad` typeclass.

To add effects to a given computation, add more `Has` constraints to the signature/carrier pair `sig` and `m`. For example, to add a `Reader` effect managing an `Int`, we would write:

```haskell
action2 :: (Has (State String) sig m, Has (Reader Int) sig m) => m ()
action2 = do
  i <- ask
  put (replicate i '!')
```

## Running effects

Effects are run with _effect handlers_, specified as functions (generally starting with `run…`) unpacking some specific monad with a `Carrier` instance. For example, we can run a `State` computation using `runState`, imported from the `Control.Carrier.State.Strict` carrier module:

```haskell
example1 :: Algebra sig m => [a] -> m (Int, ())
example1 list = runState 0 $ do
  i <- get
  put (i + length list)
```

`runState` returns a tuple of both the computed value (the `()`) and the final state (the `Int`), visible in the result of the returned computation. The `get` function is resolved with a visible type application, due to the fact that effects can contain more than one state type (in contrast with `mtl`’s `MonadState`, which limits the user to a single state type).

Since this function returns a value in some carrier `m`, effect handlers can be chained to run multiple effects. Here, we get the list to compute the length of from a `Reader` effect:

```haskell
example2 :: Algebra sig m => m (Int, ())
example2 = runReader "hello" . runState 0 $ do
  list <- ask
  put (length (list :: String))
```

(Note that the type annotation on `list` is necessary to disambiguate the requested value, since otherwise all the typechecker knows is that it’s an arbitrary `Foldable`. For more information, see the [comparison to `mtl`](#comparison-to-mtl).)

When all effects have been handled, a computation’s final value can be extracted with `run`:

```haskell
example3 :: (Int, ())
example3 = run . runReader "hello" . runState 0 $ do
  list <- ask
  put (length (list :: String))
```

`run` is itself actually an effect handler for the `Lift Identity` effect, whose only operation is to lift a result value into a computation.

Alternatively, arbitrary `Monad`s can be embedded into effectful computations using the `Lift` effect. In this case, the underlying `Monad`ic computation can be extracted using `runM`. Here, we use the `MonadIO` instance for the `LiftC` carrier to lift `putStrLn` into the middle of our computation:

```haskell
example4 :: IO (Int, ())
example4 = runM . runReader "hello" . runState 0 $ do
  list <- ask
  liftIO (putStrLn list)
  put (length list)
```

(Note that we no longer need to give a type annotation for `list`, since `putStrLn` constrains the type for us.)

## Required compiler extensions

When defining your own effects, you may need `-XKindSignatures` if GHC cannot correctly infer the type of your constructor; see the [documentation on common errors][common] for more information about this case.

When defining carriers, you’ll need `-XTypeOperators` to declare a `Carrier` instance over (`:+:`), `-XFlexibleInstances` to loosen the conditions on the instance, `-XMultiParamTypeClasses` since `Carrier` takes two parameters, and `-XUndecidableInstances` to satisfy the coverage condition for this instance.

[common]: https://github.com/fused-effects/fused-effects/blob/master/docs/common_errors.md

The following invocation, taken from the teletype example, should suffice for most use or construction of effects and carriers:

```haskell
{-# LANGUAGE FlexibleInstances, GeneralizedNewtypeDeriving, MultiParamTypeClasses, TypeOperators, UndecidableInstances #-}
```
