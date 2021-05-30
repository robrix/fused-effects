{-# LANGUAGE CPP #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

{- | The 'Algebra' class is the mechanism with which effects are interpreted.

An instance of the 'Algebra' class defines an interpretation of an effect signature atop a given monad.

@since 1.0.0.0
-}
module Control.Algebra
( Algebra(..)
, thread
, run
, Has
, send
  -- * Re-exports
, Handler
, (~<~)
, (:+:) (..)
) where

import           Control.Algebra.Handler
#if MIN_VERSION_transformers(0,5,4)
import           Control.Effect.Accum.Internal
#endif
import           Control.Effect.Catch.Internal
import           Control.Effect.Choose.Internal
import           Control.Effect.Empty.Internal
import           Control.Effect.Error.Internal
import           Control.Effect.Lift.Internal
import           Control.Effect.NonDet.Internal
import           Control.Effect.Reader.Internal
import           Control.Effect.State.Internal
import           Control.Effect.Sum ((:+:)(..), Member(..), Members)
import           Control.Effect.Throw.Internal
import           Control.Effect.Writer.Internal
#if MIN_VERSION_transformers(0,5,4)
import qualified Control.Monad.Trans.Accum as Accum
#endif
import qualified Control.Monad.Trans.Except as Except
import qualified Control.Monad.Trans.Identity as Identity
import qualified Control.Monad.Trans.Maybe as Maybe
import qualified Control.Monad.Trans.Reader as Reader
#if MIN_VERSION_transformers(0,5,6)
import qualified Control.Monad.Trans.RWS.CPS as RWS.CPS
#endif
import qualified Control.Monad.Trans.RWS.Lazy as RWS.Lazy
import qualified Control.Monad.Trans.RWS.Strict as RWS.Strict
import qualified Control.Monad.Trans.State.Lazy as State.Lazy
import qualified Control.Monad.Trans.State.Strict as State.Strict
#if MIN_VERSION_transformers(0,5,6)
import qualified Control.Monad.Trans.Writer.CPS as Writer.CPS
#endif
import qualified Control.Monad.Trans.Writer.Lazy as Writer.Lazy
import qualified Control.Monad.Trans.Writer.Strict as Writer.Strict
import           Data.Functor.Compose
import           Data.Functor.Identity
import           Data.List.NonEmpty (NonEmpty(..))
import           Data.Monoid

-- | The class of carriers (results) for algebras (effect handlers) over signatures (effects), whose actions are given by the 'alg' method.
--
-- @since 1.0.0.0
class Monad m => Algebra sig m | m -> sig where
  -- | Interpret an effect, running any nested actions using a 'Handler' starting from an initial state in @ctx@.
  --
  -- Instances receive a signature of effects containing actions in @n@ which can be lowered to @m@ using the passed 'Handler' and initial context. Continuations in @n@ can be handled after mapping into contexts returned from previous actions.
  --
  -- For example, considering the 'Algebra' instance for @'Either' e@:
  --
  -- > instance Algebra (Error e) (Either e) where
  -- >   alg hdl sig ctx = case sig of
  -- >     L (Throw e)   -> Left e
  -- >     R (Catch m h) -> either (hdl . (<$ ctx) . h) pure (hdl (m <$ ctx))
  --
  -- The 'Catch' case holds actions @m :: n x@ and @h :: e -> n x@ (for some existentially-quantified type @x@), and a continuation @k :: x -> n a@. The algebra must return @m (ctx a)@, so we have to ultimately use and lower the continuation in order to produce that type. The continuation takes an @x@, which we can get from either of the actions, after lowering them to values in @'Either' e@.
  --
  -- To that end, the algebra lifts both the action @m@ and the result of the error handler @h@ into the initial context @ctx@ before lowering them with @hdl@. The continuation @k@ is 'fmap'ed into the resulting context and then itself lowered with @hdl@.
  --
  -- By contrast, the 'Throw' case can simply return a value in 'Left', since there is no continuation to call—it represents an exceptional return—and @'Left' e :: forall a . Either e a@ (i.e. 'Left' is polymorphic in @a@).
  --
  -- Instances for monad transformers will most likely handle a signature containing multiple effects, with the tail of the signature handled by whatever monad the transformer wraps. In these cases, the tail of the signature can be delegated most conveniently using 'thread'; see the 'Algebra' instances for @transformers@ types such as 'Reader.ReaderT' and 'Except.ExceptT' for details.
  alg
    :: Functor ctx
    => Handler ctx n m -- ^ A 'Handler' lowering computations inside the effect into the carrier type @m@.
    -> sig n a         -- ^ The effect signature to be interpreted.
    -> ctx ()          -- ^ The initial state.
    -> m (ctx a)       -- ^ The interpretation of the effect in @m@.

-- | Thread a composed handler and input state through the algebra for some underlying signature.
--
-- @since 1.1.0.0
thread
  :: ( Functor ctx1
     , Functor ctx2
     , Algebra sig m
     )
  => Handler (Compose ctx1 ctx2) n m
  -> sig n a
  -> ctx1 (ctx2 ())
  -> m (ctx1 (ctx2 a))
thread hdl sig = fmap getCompose . alg hdl sig . Compose
{-# INLINE thread #-}


-- | Run an action exhausted of effects to produce its final result value.
--
-- @since 1.0.0.0
run :: Identity a -> a
run = runIdentity
{-# INLINE run #-}


-- | @m@ is a carrier for @sig@ containing @eff@.
--
-- Note that if @eff@ is a sum, it will be decomposed into multiple 'Member' constraints. While this technically allows one to combine multiple unrelated effects into a single 'Has' constraint, doing so has two significant drawbacks:
--
-- 1. Due to [a problem with recursive type families](https://gitlab.haskell.org/ghc/ghc/issues/8095), this can lead to significantly slower compiles.
--
-- 2. It defeats @ghc@’s warnings for redundant constraints, and thus can lead to a proliferation of redundant constraints as code is changed.
--
-- @since 1.0.0.0
type Has eff sig m = (Members eff sig, Algebra sig m)

-- | Construct a request for an effect to be interpreted by some handler later on.
--
-- @since 0.1.0.0
send :: (Member eff sig, Algebra sig m) => eff m a -> m a
send sig = runIdentity <$> alg (fmap Identity . runIdentity) (inj sig) (Identity ())
{-# INLINE send #-}


-- base

instance Algebra (Lift IO) IO where
  alg hdl (LiftWith with) = with hdl
  {-# INLINE alg #-}

instance Algebra (Lift Identity) Identity where
  alg hdl (LiftWith with) = with hdl
  {-# INLINE alg #-}

instance Algebra Choose NonEmpty where
  alg _ Choose ctx = (True <$ ctx) :| [ False <$ ctx ]
  {-# INLINE alg #-}

instance Algebra Empty Maybe where
  alg _ Empty _ = Nothing
  {-# INLINE alg #-}

instance Algebra (Error e) (Either e) where
  alg hdl sig ctx = case sig of
    L (Throw e)   -> Left e
    R (Catch m h) -> either (hdl . (<$ ctx) . h) pure (hdl (m <$ ctx))
  {-# INLINE alg #-}

instance Algebra (Reader r) ((->) r) where
  alg hdl sig ctx = case sig of
    Ask       -> (<$ ctx)
    Local f m -> hdl (m <$ ctx) . f
  {-# INLINE alg #-}

instance Algebra NonDet [] where
  alg _ sig ctx = case sig of
    L Empty  -> []
    R Choose -> [ True <$ ctx, False <$ ctx ]
  {-# INLINE alg #-}

instance Monoid w => Algebra (Writer w) ((,) w) where
  alg hdl sig ctx = case sig of
    Tell w     -> (w, ctx)
    Listen m   -> let (w, a) = hdl (m <$ ctx) in (w, (,) w <$> a)
    Censor f m -> let (w, a) = hdl (m <$ ctx) in (f w, a)
  {-# INLINE alg #-}


-- transformers

instance Algebra sig m => Algebra (Error e :+: sig) (Except.ExceptT e m) where
  alg hdl sig ctx = case sig of
    L (L (Throw e))   -> Except.throwE e
    L (R (Catch m h)) -> Except.catchE (hdl (m <$ ctx)) (hdl . (<$ ctx) . h)
    R other           -> Except.ExceptT $ thread (either (pure . Left) Except.runExceptT ~<~ hdl) other (Right ctx)
  {-# INLINE alg #-}


deriving instance Algebra sig m => Algebra sig (Identity.IdentityT m)

#if MIN_VERSION_base(4,12,0)
-- | This instance permits effectful actions to be lifted into the 'Ap' monad
-- given a monoidal return type, which can provide clarity when chaining calls
-- to 'mappend'.
--
-- > mappend <$> act1 <*> (mappend <$> act2 <*> act3)
--
-- is equivalent to
--
-- > getAp (act1 <> act2 <> act3)
--
-- @since 1.0.1.0
deriving instance Algebra sig m => Algebra sig (Ap m)
#endif

-- | This instance permits effectful actions to be lifted into the 'Alt' monad,
-- which eases the invocation of repeated alternation with 'Control.Applicative.<|>':
--
-- > a <|> b <|> c <|> d
--
-- is equivalent to
--
-- > getAlt (mconcat [a, b, c, d])
--
-- @since 1.0.1.0
deriving instance Algebra sig m => Algebra sig (Alt m)


instance Algebra sig m => Algebra (Empty :+: sig) (Maybe.MaybeT m) where
  alg hdl sig ctx = case sig of
    L Empty -> Maybe.MaybeT (pure Nothing)
    R other -> Maybe.MaybeT $ thread (maybe (pure Nothing) Maybe.runMaybeT ~<~ hdl) other (Just ctx)
  {-# INLINE alg #-}


instance Algebra sig m => Algebra (Reader r :+: sig) (Reader.ReaderT r m) where
  alg hdl sig ctx = case sig of
    L Ask         -> Reader.asks (<$ ctx)
    L (Local f m) -> Reader.local f (hdl (m <$ ctx))
    R other       -> Reader.ReaderT $ \ r -> alg ((`Reader.runReaderT` r) . hdl) other ctx
  {-# INLINE alg #-}


newtype RWSTF w s a = RWSTF { unRWSTF :: (a, s, w) }
  deriving (Functor)

toRWSTF :: Monoid w => w -> (a, s, w) -> RWSTF w s a
toRWSTF w (a, s, w') = RWSTF (a, s, mappend w w')
{-# INLINE toRWSTF #-}

newtype Swap s a = Swap { getSwap :: (a, s) }
  deriving (Functor)

swapAndLift :: Functor ctx => (ctx a, w) -> ctx (w, a)
swapAndLift p = (,) (snd p) <$> fst p
{-# INLINE swapAndLift #-}

#if MIN_VERSION_transformers(0,5,6)
instance (Algebra sig m, Monoid w) => Algebra (Reader r :+: Writer w :+: State s :+: sig) (RWS.CPS.RWST r w s m) where
  alg hdl sig ctx = case sig of
    L Ask              -> RWS.CPS.asks (<$ ctx)
    L (Local f m)      -> RWS.CPS.local f (hdl (m <$ ctx))
    R (L (Tell w))     -> ctx <$ RWS.CPS.tell w
    R (L (Listen m))   -> swapAndLift <$> RWS.CPS.listen (hdl (m <$ ctx))
    R (L (Censor f m)) -> RWS.CPS.censor f (hdl (m <$ ctx))
    R (R (L Get))      -> RWS.CPS.gets (<$ ctx)
    R (R (L (Put s)))  -> ctx <$ RWS.CPS.put s
    R (R (R other))    -> RWS.CPS.rwsT $ \ r s -> unRWSTF <$> thread ((\ (RWSTF (x, s, w)) -> toRWSTF w <$> RWS.CPS.runRWST x r s) ~<~ hdl) other (RWSTF (ctx, s, mempty))
  {-# INLINE alg #-}
#endif

instance (Algebra sig m, Monoid w) => Algebra (Reader r :+: Writer w :+: State s :+: sig) (RWS.Lazy.RWST r w s m) where
  alg hdl sig ctx = case sig of
    L Ask              -> RWS.Lazy.asks (<$ ctx)
    L (Local f m)      -> RWS.Lazy.local f (hdl (m <$ ctx))
    R (L (Tell w))     -> ctx <$ RWS.Lazy.tell w
    R (L (Listen m))   -> swapAndLift <$> RWS.Lazy.listen (hdl (m <$ ctx))
    R (L (Censor f m)) -> RWS.Lazy.censor f (hdl (m <$ ctx))
    R (R (L Get))      -> RWS.Lazy.gets (<$ ctx)
    R (R (L (Put s)))  -> ctx <$ RWS.Lazy.put s
    R (R (R other))    -> RWS.Lazy.RWST $ \ r s -> unRWSTF <$> thread ((\ (RWSTF (x, s, w)) -> toRWSTF w <$> RWS.Lazy.runRWST x r s) ~<~ hdl) other (RWSTF (ctx, s, mempty))
  {-# INLINE alg #-}

instance (Algebra sig m, Monoid w) => Algebra (Reader r :+: Writer w :+: State s :+: sig) (RWS.Strict.RWST r w s m) where
  alg hdl sig ctx = case sig of
    L Ask              -> RWS.Strict.asks (<$ ctx)
    L (Local f m)      -> RWS.Strict.local f (hdl (m <$ ctx))
    R (L (Tell w))     -> ctx <$ RWS.Strict.tell w
    R (L (Listen m))   -> swapAndLift <$> RWS.Strict.listen (hdl (m <$ ctx))
    R (L (Censor f m)) -> RWS.Strict.censor f (hdl (m <$ ctx))
    R (R (L Get))      -> RWS.Strict.gets (<$ ctx)
    R (R (L (Put s)))  -> ctx <$ RWS.Strict.put s
    R (R (R other))    -> RWS.Strict.RWST $ \ r s -> unRWSTF <$> thread ((\ (RWSTF (x, s, w)) -> toRWSTF w <$> RWS.Strict.runRWST x r s) ~<~ hdl) other (RWSTF (ctx, s, mempty))
  {-# INLINE alg #-}


instance Algebra sig m => Algebra (State s :+: sig) (State.Lazy.StateT s m) where
  alg hdl sig ctx = case sig of
    L Get     -> State.Lazy.gets (<$ ctx)
    L (Put s) -> ctx <$ State.Lazy.put s
    R other   -> State.Lazy.StateT $ \ s -> getSwap <$> thread (fmap Swap . uncurry State.Lazy.runStateT . getSwap ~<~ hdl) other (Swap (ctx, s))
  {-# INLINE alg #-}

instance Algebra sig m => Algebra (State s :+: sig) (State.Strict.StateT s m) where
  alg hdl sig ctx = case sig of
    L Get     -> State.Strict.gets (<$ ctx)
    L (Put s) -> ctx <$ State.Strict.put s
    R other   -> State.Strict.StateT $ \ s -> getSwap <$> thread (fmap Swap . uncurry State.Strict.runStateT . getSwap ~<~ hdl) other (Swap (ctx, s))
  {-# INLINE alg #-}


#if MIN_VERSION_transformers(0,5,6)
instance (Algebra sig m, Monoid w) => Algebra (Writer w :+: sig) (Writer.CPS.WriterT w m) where
  alg hdl sig ctx = case sig of
    L (Tell w)     -> ctx <$ Writer.CPS.tell w
    L (Listen m)   -> swapAndLift <$> Writer.CPS.listen (hdl (m <$ ctx))
    L (Censor f m) -> Writer.CPS.censor f (hdl (m <$ ctx))
    R other        -> Writer.CPS.writerT $ getSwap <$> thread ((\ (Swap (x, s)) -> Swap . fmap (mappend s) <$> Writer.CPS.runWriterT x) ~<~ hdl) other (Swap (ctx, mempty))
  {-# INLINE alg #-}
#endif

instance (Algebra sig m, Monoid w) => Algebra (Writer w :+: sig) (Writer.Lazy.WriterT w m) where
  alg hdl sig ctx = case sig of
    L (Tell w)     -> ctx <$ Writer.Lazy.tell w
    L (Listen m)   -> swapAndLift <$> Writer.Lazy.listen (hdl (m <$ ctx))
    L (Censor f m) -> Writer.Lazy.censor f (hdl (m <$ ctx))
    R other        -> Writer.Lazy.WriterT $ getSwap <$> thread ((\ (Swap (x, s)) -> Swap . fmap (mappend s) <$> Writer.Lazy.runWriterT x) ~<~ hdl) other (Swap (ctx, mempty))
  {-# INLINE alg #-}

instance (Algebra sig m, Monoid w) => Algebra (Writer w :+: sig) (Writer.Strict.WriterT w m) where
  alg hdl sig ctx = case sig of
    L (Tell w)     -> ctx <$ Writer.Strict.tell w
    L (Listen m)   -> swapAndLift <$> Writer.Strict.listen (hdl (m <$ ctx))
    L (Censor f m) -> Writer.Strict.censor f (hdl (m <$ ctx))
    R other        -> Writer.Strict.WriterT $ getSwap <$> thread ((\ (Swap (x, s)) -> Swap . fmap (mappend s) <$> Writer.Strict.runWriterT x) ~<~ hdl) other (Swap (ctx, mempty))
  {-# INLINE alg #-}

#if MIN_VERSION_transformers(0,5,4)
instance (Algebra sig m, Monoid w) => Algebra (Accum w :+: sig) (Accum.AccumT w m) where
  alg hdl sig ctx = case sig of
    L (Add w) -> ctx <$ Accum.add w
    L Look    -> Accum.looks (<$ ctx)
    R other   -> Accum.AccumT $ \w -> getSwap <$> thread ((\(Swap (x, s)) -> Swap . fmap (mappend s) <$> Accum.runAccumT x s) ~<~ hdl) other (Swap (ctx, w))
  {-# INLINE alg #-}
#endif
