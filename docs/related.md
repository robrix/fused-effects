# Related work

`fused-effects` is an encoding of higher-order algebraic effects following the recipes in _[Effect Handlers in Scope][]_ (Nicolas Wu, Tom Schrijvers, Ralf Hinze), _[Monad Transformers and Modular Algebraic Effects: What Binds Them Together][]_ (Tom Schrijvers, Maciej Piróg, Nicolas Wu, Mauro Jaskelioff), and _[Fusion for Free—Efficient Algebraic Effect Handlers][]_ (Nicolas Wu, Tom Schrijvers).

[effect handlers in scope]: http://www.cs.ox.ac.uk/people/nicolas.wu/papers/Scope.pdf
[monad transformers and modular algebraic effects: what binds them together]: http://www.cs.kuleuven.be/publicaties/rapporten/cw/CW699.pdf
[fusion for free—efficient algebraic effect handlers]: https://people.cs.kuleuven.be/~tom.schrijvers/Research/papers/mpc2015.pdf

## Contributed packages

Though we aim to keep the `fused-effects` core minimal, we encourage the development of external `fused-effects`-compatible libraries. If you’ve written one that you’d like to be mentioned here, get in touch!

- [`fused-effects-lens`][felens] provides combinators to use the [`lens`][lens] library fluently inside effectful computations.
- [`fused-effects-exceptions`][exc] provides handlers for exceptions thrown in the `IO` monad.
- [`fused-effects-resumable`][] provides resumable exceptions, which can also serve as a limited form of coroutines.
- [`fused-effects-mwc-random`][] provides a performant, high-quality source of random data, as well as values from common numerical distributions.
- [`fused-effects-readline`][] provides a REPL effect that interfaces with [`haskeline`][] for its UI.
- [`fused-effects-parser`][] provides parser-combinator style effects similar to parsing libraries such as [`trifecta`][].

[exc]: https://github.com/fused-effects/fused-effects-exceptions
[felens]: http://hackage.haskell.org/package/fused-effects-lens
[`fused-effects-mwc-random`]: https://github.com/fused-effects/fused-effects-mwc-random
[`fused-effects-resumable`]: https://github.com/fused-effects/fused-effects-resumable
[`fused-effects-readline`]: https://github.com/fused-effects/fused-effects-readline
[`haskeline`]: https://hackage.haskell.org/package/haskeline
[`fused-effects-parser`]: https://github.com/fused-effects/fused-effects-parser
[`trifecta`]: https://hackage.haskell.org/package/trifecta
[lens]: http://hackage.haskell.org/package/lens

## Projects using `fused-effects`

- [`semantic`](http://github.com/github/semantic), a program analysis toolkit
- [`now-haskell`](http://hackage.haskell.org/package/now-haskell), a client library for AWS Lambda

## Comparison to other effect libraries

### Comparison to `mtl`

Like [`mtl`][], `fused-effects` provides a library of monadic effects which can be given different interpretations. In `mtl` this is done by defining new instances of the typeclasses encoding the actions of the effect, e.g. `MonadState`. In `fused-effects`, this is done by defining new instances of the `Carrier` typeclass for the effect.

Also like `mtl`, `fused-effects` allows scoped operations like `local` and `catchError` to be given different interpretations. As with first-order operations, `mtl` achieves this with a final tagless encoding via methods, whereas `fused-effects` achieves this with an initial algebra encoding via `Carrier` instances.

In addition, `mtl` and `fused-effects` are similar in that they provide instances for the monad types defined in the `transformers` package (`Control.Monad.Reader`, `Control.Monad.Writer`, etc). This means that applications using `mtl` can migrate many existing `transformers`-based monad stacks to `fused-effects` with minimal code changes. `fused-effects` provides its own hierarchy of carrier monads (under the `Control.Carrier` namespace) that provide a more fluent interface for new code, though it may be useful to use `transformers` types when working with third-party libraries.

Unlike `mtl`, effects are automatically available regardless of where they occur in the signature; in `mtl` this requires instances for all valid orderings of the transformers (O(n²) of them, in general).

Also unlike `mtl`, there can be more than one `State` or `Reader` effect in a signature. This is a tradeoff: `mtl` is able to provide excellent type inference for effectful operations like `get`, since the functional dependencies can resolve the state type from the monad type.

Unlike `fused-effects`, `mtl` provides a `ContT` monad transformer; however, it’s worth noting that many behaviours possible with delimited continuations (e.g. resumable exceptions) are directly encodable as effects.

Finally, thanks to the fusion and inlining of carriers, `fused-effects` is only marginally slower than equivalent `mtl` code (see [benchmarks](#benchmarks)).

[`mtl`]: http://hackage.haskell.org/package/mtl

### Comparison to `freer-simple`

Like [`freer-simple`][], `fused-effects` uses an initial encoding of library- and user-defined effects as syntax which can then be given different interpretations. In `freer-simple`, this is done with a family of interpreter functions (which cover a variety of needs, and which can be extended for more bespoke needs), whereas in `fused-effects` this is done with `Carrier` instances for `newtype`s.

Unlike `fused-effects`, in `freer-simple`, scoped operations like `catchError` and `local` are implemented as interpreters, and can therefore not be given new interpretations.

Unlike `freer-simple`, `fused-effects` has relatively little attention paid to compiler error messaging, which can make common (compile-time) errors somewhat more confusing to diagnose. Similarly, `freer-simple`’s family of interpreter functions can make the job of defining new effect handlers somewhat easier than in `fused-effects`. Further, `freer-simple` provides many of the same effects as `fused-effects`, plus a coroutine effect, but minus resource management and random generation.

Finally, `fused-effects` has been [benchmarked](#benchmarks) as faster than `freer-simple`.

[`freer-simple`]: http://hackage.haskell.org/package/freer-simple

### Comparison to `polysemy`

Like [`polysemy`](http://hackage.haskell.org/package/polysemy), `fused-effects` is a batteries-included effect system capable of scoped, reinterpretable algebraic effects.

As of GHC 8.8, `fused-effects` outperforms `polysemy`, though new effects take more code to define in `fused-effects` than `polysemy` (though the `Control.Carrier.Interpret` module provides a low-friction API for rapid prototyping of new effects). Like `freer-simple` and unlike `fused-effects`, polysemy provides custom type errors if a given effect invocation is ambigous or invalid in the current context.

### Comparison to `eff`

[`eff`](https://github.com/lexi-lambda/eff) is similar in many ways to `fused-effects`, but is slightly more performant due to its representation of effects as typeclasses. This approach lets GHC generate better code in exchange for sacrificing the flexibility associated with effects represented as data types. `eff` also uses the `monad-control` package to lift effects between contexts rather than implementing an `Algebra`-style class itself.

## Acknowledgements

The authors of fused-effects would like to thank:

- Tom Schrijvers, Nicholas Wu, and all their collaborators for the research that led to `fused-effects`;
- Alexis King for thoughtful discussions about and suggestions regarding our methodology;
- the authors of other effect libraries, including `eff`, `polysemy`, and `capabilities`, for their exploration of the space.
