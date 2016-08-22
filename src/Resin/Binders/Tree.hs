{-# LANGUAGE FlexibleContexts,FlexibleInstances,GADTs,DataKinds, PolyKinds, KindSignatures #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE TypeInType #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BangPatterns #-}

module Resin.Binders.Tree where
import Data.Kind
import Numeric.Natural
import Data.Semigroupoid
import Data.Coerce
import Data.Type.Equality


data Inject :: (k -> Type ) -> k -> k -> Type where
  PolyId :: forall f a . Inject f a a
  MonoId :: forall f  i .  (f i) -> Inject f i i
  CompactCompose :: forall f i j . (f i) -> (f j)  -> Natural -> Inject f i j  -- i is origin/root j is leaf

instance Semigroupoid (Inject f) where
   --PolyId `o`  PolyId =  PolyId
   PolyId `o` (!f) = f
   (MonoId _g) `o` (!f) = f
   cc@(CompactCompose _ _ _) `o` (MonoId _) = cc
   cc@(CompactCompose _ _ _) `o` PolyId = cc
   (CompactCompose _cmiddle2 cout sizeleft)
    `o` (CompactCompose cin _cmiddle1 sizeright) = CompactCompose cin cout (sizeright + sizeleft)
      --- TODO is this case to lazy?


newtype Extract :: (k -> Type ) -> k -> k -> Type where
  ExtractCon :: (Inject f a b) -> Extract f a b

instance Semigroupoid (Extract f) where
  o = \ l  r -> ExtractCon  $ coerce l  `o` coerce r


data TreeEq :: (k -> Type ) -> k -> k -> Type where
  TreeInject :: Inject f a b -> TreeEq f a b
  TreeExtract :: Extract f a b -> TreeEq f a b
  TreeRefl :: TreeEq f c c

--- this might limit a,c to being kind (or sort?) * / Type for now, but thats OK ??
treeElimination :: TestEquality f => Inject f a b -> Extract f b c -> {- Maybe Wrapped? -} Maybe (TreeEq f a c)
treeElimination (MonoId fa) (ExtractCon (MonoId fb)) = case testEquality fa fb of
                                                          Just (Refl) -> Just TreeRefl
                                                          Nothing -> Nothing
-- FINISH the rest of the cases


{-
is extract literally the same datastructure just with a fresh name?

-}