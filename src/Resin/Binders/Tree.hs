{-# LANGUAGE FlexibleContexts,FlexibleInstances,GADTs,DataKinds, PolyKinds, KindSignatures #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE TypeInType #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE TypeOperators #-}

module Resin.Binders.Tree where
import Data.Kind
import Numeric.Natural
import Data.Semigroupoid
--import Data.Coerce
import Unsafe.Coerce (unsafeCoerce)
import Data.Type.Equality
--import qualified Data.Semigroupoid.Dual as DL


{-
This module models binders which respect scope having a tree shaped topology
or at least it models some ideas about (finite?) paths on  (finite??!) trees

-}


data IxEq :: (k -> Type ) -> k -> k   -> Type where
   PolyRefl ::  IxEq f i i
   MonoRefl :: forall f i . f i -> IxEq f i i

--testIxEquality :: TestEquality f => IxEq f a b -> IxEq f b c ->

instance TestEquality f => TestEquality (IxEq f i) where
  testEquality (MonoRefl f1) (MonoRefl f2) = testEquality f1 f2
  testEquality (PolyRefl  )(MonoRefl _f2) = Just Refl
  testEquality (MonoRefl _f1) (PolyRefl  ) = Just Refl
  testEquality (PolyRefl ) (PolyRefl ) = Just Refl

{- | `Inject` is about

-}
data Inject :: (k -> Type ) -> k -> k -> Type where
  InjectRefl :: forall f a b . IxEq f a b->  Inject f a b
  --MonoId :: forall f  i .  (f i) -> Inject f i i
  -- should MonoId be strict in its argument?
  CompactCompose :: forall f i j . (IxEq f i i) -> (IxEq f  j j  )  -> Natural -> Inject f i j
   -- i is origin/root
   -- j is leaf
  -- compact compose is unsafe for users, but should be exposed in a .Internal
  -- module



instance Semigroupoid (Inject f) where
   --PolyId `o`  PolyId =  PolyId
   (InjectRefl (MonoRefl _p)) `o` (!f) = f
   (InjectRefl (PolyRefl)) `o`  (!f) = f
   (CompactCompose in1 out1 size) `o` (InjectRefl  (PolyRefl)) = CompactCompose  in1 out1 size
   (CompactCompose in1 out1 size) `o` (InjectRefl  (MonoRefl !_p)) = CompactCompose  in1 out1 size
   (CompactCompose _cmiddle2 cout sizeleft)
    `o` (CompactCompose cin _cmiddle1 sizeright) = CompactCompose cin cout (sizeright + sizeleft)
      --- TODO is this case to lazy?

-- extract is the dual of Inject
-- aka Data.Semigroupoid.Dual is nearly the exact same type :)
newtype Extract :: (k -> Type ) -> k -> k -> Type where
  Dual :: ((Inject f) b a ) -> Extract f a b
-- not sure if this is the right design vs
  -- :: Inject f b a -> Extract f a b  --- (which has more explicit duality and less newtypery)


instance Semigroupoid (Extract f) where
  o = \ (Dual l)  (Dual r) -> Dual  $  r `o` l


data TreeEq :: (k -> Type ) -> k -> k -> Type where
  TreeInject :: Inject f a b -> TreeEq f a b
  TreeExtract :: Extract f a b -> TreeEq f a b
  TreeRefl :: TreeEq f c c


--- this might limit a,c to being kind (or sort?) * / Type for now, but thats OK ??
treeElimination :: TestEquality f => Inject f a b -> Extract f  b  c->  (TreeEq f a c)
treeElimination (InjectRefl PolyRefl) (Dual  (InjectRefl PolyRefl)) =  TreeRefl
treeElimination (InjectRefl (MonoRefl _p1)) (Dual  (InjectRefl PolyRefl)) =  TreeRefl
treeElimination (InjectRefl PolyRefl) (Dual  (InjectRefl (MonoRefl _p2))) =  TreeRefl
treeElimination (InjectRefl (MonoRefl _p1)) (Dual (InjectRefl(MonoRefl _p2))) =  TreeRefl
treeElimination (CompactCompose fa _fb1 n1) (Dual (CompactCompose fc _fb2 n2)) =
         case (compare n1 n2, max n1 n2 - min n1 n2) of
                        (EQ, _ )-> (unsafeCoerce TreeRefl) :: TreeEq f a c
                          --- if the path is zero length they must be equal!
                          --- AUDIT MEEEE
                        (GT, m )->  TreeInject (CompactCompose fa fc  m)
                        (LT, m ) -> TreeExtract (Dual (CompactCompose fc fa m))
treeElimination   (InjectRefl p@(PolyRefl))
                  d@(Dual (CompactCompose _fc _fb _n)) = treeElimination (CompactCompose p p 0) d
treeElimination   (InjectRefl p@(MonoRefl _))
                  d@(Dual (CompactCompose _fc _fb _n)) = treeElimination (CompactCompose p p 0) d
treeElimination   d@( CompactCompose _fc _fb _n)
                  (Dual (InjectRefl p@(PolyRefl))) = treeElimination d (Dual (CompactCompose p p 0))
treeElimination   d@(CompactCompose _fc _fb _n)
                  (Dual (InjectRefl p@(MonoRefl _))) = treeElimination d (Dual (CompactCompose p p 0))

