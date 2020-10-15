{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Torch.GraduallyTyped.DType where

import Data.Kind (Type)
import Torch.DType (DType (..))
import Type.Errors.Pretty (TypeError, type (%), type (<>))

class KnownDType (dType :: DType) where
  dTypeVal :: DType

instance KnownDType 'Bool where
  dTypeVal = Bool

instance KnownDType 'UInt8 where
  dTypeVal = UInt8

instance KnownDType 'Int8 where
  dTypeVal = Int8

instance KnownDType 'Int16 where
  dTypeVal = Int16

instance KnownDType 'Int32 where
  dTypeVal = Int32

instance KnownDType 'Int64 where
  dTypeVal = Int64

instance KnownDType 'Half where
  dTypeVal = Half

instance KnownDType 'Float where
  dTypeVal = Float

instance KnownDType 'Double where
  dTypeVal = Double

-- | Data type to represent whether or not the tensor data type is checked, that is, known to the compiler.
data DataType (dType :: Type) where
  -- | The tensor data type is unknown to the compiler.
  UncheckedDataType :: forall dType. DataType dType
  -- | The tensor data type is known to the compiler.
  DataType :: forall dType. dType -> DataType dType
  deriving (Show)

class KnownDataType (dataType :: DataType DType) where
  dataTypeVal :: DataType DType

instance KnownDataType 'UncheckedDataType where
  dataTypeVal = UncheckedDataType

instance
  (KnownDType dType) =>
  KnownDataType ( 'DataType dType)
  where
  dataTypeVal = DataType (dTypeVal @dType)

class WithDataTypeC (isAnyDataType :: Bool) (dataType :: DataType DType) (f :: Type) where
  type WithDataTypeF isAnyDataType f :: Type
  withDataType :: (DType -> f) -> WithDataTypeF isAnyDataType f

instance WithDataTypeC 'True dataType f where
  type WithDataTypeF 'True f = DType -> f
  withDataType = id

instance (KnownDataType dataType) => WithDataTypeC 'False dataType f where
  type WithDataTypeF 'False f = f
  withDataType f = case dataTypeVal @dataType of DataType dataType -> f dataType

type family UnifyDataTypeF (dataType :: DataType DType) (dataType' :: DataType DType) :: DataType DType where
  UnifyDataTypeF 'UncheckedDataType 'UncheckedDataType = 'UncheckedDataType
  UnifyDataTypeF ( 'DataType _) 'UncheckedDataType = 'UncheckedDataType
  UnifyDataTypeF 'UncheckedDataType ( 'DataType _) = 'UncheckedDataType
  UnifyDataTypeF ( 'DataType dType) ( 'DataType dType) = 'DataType dType
  UnifyDataTypeF ( 'DataType dType) ( 'DataType dType') =
    TypeError
      ( "The supplied tensors must have the same data type, "
          % "but different data types were found:"
          % ""
          % "    " <> dType <> " and " <> dType' <> "."
          % ""
      )