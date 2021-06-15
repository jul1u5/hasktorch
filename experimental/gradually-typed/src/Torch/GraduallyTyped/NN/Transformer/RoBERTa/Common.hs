{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Torch.GraduallyTyped.NN.Transformer.RoBERTa.Common where

import Control.Monad.Reader (ReaderT (runReaderT))
import Data.Kind (Type)
import GHC.Generics (Generic)
import GHC.TypeLits (Nat, Symbol)
import GHC.TypeNats (type (<=?))
import Torch.DType (DType (..))
import Torch.GraduallyTyped.DType (DataType (..))
import Torch.GraduallyTyped.Device (Device (..), DeviceType (..))
import Torch.GraduallyTyped.Layout (Layout (..), LayoutType (..))
import Torch.GraduallyTyped.NN.Class (HasInitialize (..))
import Torch.GraduallyTyped.NN.Transformer.Encoder (TransformerEncoder, lookupEncoder)
import Torch.GraduallyTyped.NN.Transformer.EncoderOnly (EncoderOnlyTransformer (..), EncoderOnlyTransformerWithLMHead (..), lookupEncoderOnlyTransformer, lookupEncoderOnlyTransformerWithLMHead)
import Torch.GraduallyTyped.NN.Transformer.Stack (HasLookupStack)
import Torch.GraduallyTyped.NN.Transformer.Type (TensorDict, TransformerStyle (RoBERTa), mkTransformerInput, mkTransformerPaddingMask, tensorDictFromPretrained)
import Torch.GraduallyTyped.Prelude (Seq)
import Torch.GraduallyTyped.RequiresGradient (RequiresGradient (..))
import Torch.GraduallyTyped.Shape.Class (BroadcastShapesF)
import Torch.GraduallyTyped.Shape.Type (Dim (..), KnownDim, Name (..), Shape (..), Size (..), WithDimC (..))
import Torch.GraduallyTyped.Tensor.Type (Tensor)
import Torch.GraduallyTyped.Unify (type (<+>))

-- | RoBERTa dType.
type RoBERTaDType = 'Float

-- | RoBERTa data type.
type RoBERTaDataType = 'DataType RoBERTaDType

-- | RoBERTa dropout probability type.
type RoBERTaDropoutP = Float

-- | RoBERTa dropout rate.
-- 'dropout_rate = 0.1'
robertaDropoutP :: RoBERTaDropoutP
robertaDropoutP = 0.1

-- | RoBERTa positional encoding dimension.
--
-- Note the two extra dimensions.
type RoBERTaPosEncDim = 'Dim ('Name "*") ('Size 514)

-- | RoBERTa layer-norm epsilon.
-- 'layer_norm_epsilon = 1e-5'
robertaEps :: Double
robertaEps = 1e-5

-- | RoBERTa maximum number of position embeddings.
-- 'max_position_embeddings = 514'
robertaMaxPositionEmbeddings :: Int
robertaMaxPositionEmbeddings = 514

-- | RoBERTa padding token id.
-- 'pad_token_id = 1'
robertaPadTokenId :: Int
robertaPadTokenId = 1

-- | RoBERTa begin-of-sentence token id.
-- 'bos_token_id = 0'
robertaBOSTokenId :: Int
robertaBOSTokenId = 0

-- | RoBERTa end-of-sentence token id.
-- 'eos_token_id = 0'
robertaEOSTokenId :: Int
robertaEOSTokenId = 2

-- | RoBERTa attention mask bias
robertaAttentionMaskBias :: Double
robertaAttentionMaskBias = -10000

-- | RoBERTa model.
newtype
  RoBERTaModel
    (numLayers :: Nat)
    (device :: Device (DeviceType Nat))
    (headDim :: Dim (Name Symbol) (Size Nat))
    (headEmbedDim :: Dim (Name Symbol) (Size Nat))
    (embedDim :: Dim (Name Symbol) (Size Nat))
    (inputEmbedDim :: Dim (Name Symbol) (Size Nat))
    (ffnDim :: Dim (Name Symbol) (Size Nat))
    (vocabDim :: Dim (Name Symbol) (Size Nat))
    (typeVocabDim :: Dim (Name Symbol) (Size Nat))
  where
  RoBERTaModel ::
    forall numLayers device headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim.
    RoBERTaModelEncoderF RoBERTaModel numLayers device headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim ->
    RoBERTaModel numLayers device headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim
  deriving stock (Generic)

-- | RoBERTa model with language modelling head.
newtype
  RoBERTaModelWithLMHead
    (numLayers :: Nat)
    (device :: Device (DeviceType Nat))
    (headDim :: Dim (Name Symbol) (Size Nat))
    (headEmbedDim :: Dim (Name Symbol) (Size Nat))
    (embedDim :: Dim (Name Symbol) (Size Nat))
    (inputEmbedDim :: Dim (Name Symbol) (Size Nat))
    (ffnDim :: Dim (Name Symbol) (Size Nat))
    (vocabDim :: Dim (Name Symbol) (Size Nat))
    (typeVocabDim :: Dim (Name Symbol) (Size Nat))
  where
  RoBERTaModelWithLMHead ::
    forall numLayers device headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim.
    RoBERTaModelEncoderF RoBERTaModelWithLMHead numLayers device headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim ->
    RoBERTaModelWithLMHead numLayers device headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim
  deriving stock (Generic)

type family
  RoBERTaModelEncoderF
    ( robertaModel ::
        Nat ->
        Device (DeviceType Nat) ->
        Dim (Name Symbol) (Size Nat) ->
        Dim (Name Symbol) (Size Nat) ->
        Dim (Name Symbol) (Size Nat) ->
        Dim (Name Symbol) (Size Nat) ->
        Dim (Name Symbol) (Size Nat) ->
        Dim (Name Symbol) (Size Nat) ->
        Dim (Name Symbol) (Size Nat) ->
        Type
    )
    (numLayers :: Nat)
    (device :: Device (DeviceType Nat))
    (headDim :: Dim (Name Symbol) (Size Nat))
    (headEmbedDim :: Dim (Name Symbol) (Size Nat))
    (embedDim :: Dim (Name Symbol) (Size Nat))
    (inputEmbedDim :: Dim (Name Symbol) (Size Nat))
    (ffnDim :: Dim (Name Symbol) (Size Nat))
    (vocabDim :: Dim (Name Symbol) (Size Nat))
    (typeVocabDim :: Dim (Name Symbol) (Size Nat)) ::
    Type
  where
  RoBERTaModelEncoderF RoBERTaModel numLayers device headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim =
    EncoderOnlyTransformer
      numLayers
      'RoBERTa
      device
      RoBERTaDataType
      headDim
      headEmbedDim
      embedDim
      inputEmbedDim
      ffnDim
      RoBERTaPosEncDim
      vocabDim
      typeVocabDim
      RoBERTaDropoutP
  RoBERTaModelEncoderF RoBERTaModelWithLMHead numLayers device headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim =
    EncoderOnlyTransformerWithLMHead
      numLayers
      'RoBERTa
      device
      RoBERTaDataType
      headDim
      headEmbedDim
      embedDim
      inputEmbedDim
      ffnDim
      RoBERTaPosEncDim
      vocabDim
      typeVocabDim
      RoBERTaDropoutP

instance
  ( KnownDim headDim,
    KnownDim headEmbedDim,
    KnownDim embedDim,
    KnownDim ffnDim,
    KnownDim inputEmbedDim,
    KnownDim vocabDim,
    KnownDim typeVocabDim,
    HasLookupStack numLayers (1 <=? numLayers) numLayers 'RoBERTa ('Device 'CPU) RoBERTaDataType headDim headEmbedDim embedDim inputEmbedDim ffnDim RoBERTaDropoutP (ReaderT TensorDict IO)
  ) =>
  HasInitialize (RoBERTaModel numLayers ('Device 'CPU) headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim)
  where
  type
    InitializeF (RoBERTaModel numLayers ('Device 'CPU) headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim) =
      FilePath -> IO (RoBERTaModel numLayers ('Device 'CPU) headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim)
  initialize filePath =
    do
      tensorDict <- tensorDictFromPretrained filePath
      flip runReaderT tensorDict $
        RoBERTaModel <$> lookupEncoderOnlyTransformer robertaDropoutP robertaEps "roberta."

instance
  ( KnownDim headDim,
    KnownDim headEmbedDim,
    KnownDim embedDim,
    KnownDim ffnDim,
    KnownDim inputEmbedDim,
    KnownDim vocabDim,
    KnownDim typeVocabDim,
    HasLookupStack numLayers (1 <=? numLayers) numLayers 'RoBERTa ('Device 'CPU) RoBERTaDataType headDim headEmbedDim embedDim inputEmbedDim ffnDim RoBERTaDropoutP (ReaderT TensorDict IO)
  ) =>
  HasInitialize (RoBERTaModelWithLMHead numLayers ('Device 'CPU) headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim)
  where
  type
    InitializeF (RoBERTaModelWithLMHead numLayers ('Device 'CPU) headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim) =
      FilePath -> IO (RoBERTaModelWithLMHead numLayers ('Device 'CPU) headDim headEmbedDim embedDim inputEmbedDim ffnDim vocabDim typeVocabDim)
  initialize filePath =
    do
      tensorDict <- tensorDictFromPretrained filePath
      flip runReaderT tensorDict $
        RoBERTaModelWithLMHead <$> lookupEncoderOnlyTransformerWithLMHead robertaDropoutP robertaEps ""

mkRoBERTaInput ::
  forall batchDim seqDim m output.
  ( MonadFail m,
    WithDimC batchDim (WithDimF seqDim ([[Int]] -> m output)),
    WithDimC seqDim ([[Int]] -> m output),
    KnownDim batchDim,
    KnownDim seqDim,
    output
      ~ Tensor
          'WithoutGradient
          ('Layout 'Dense)
          ('Device 'CPU)
          ('DataType 'Int64)
          ('Shape '[batchDim, seqDim])
  ) =>
  WithDimF batchDim (WithDimF seqDim ([[Int]] -> m output))
mkRoBERTaInput = mkTransformerInput @batchDim @seqDim @m robertaPadTokenId

mkRoBERTaPaddingMask ::
  Tensor requiresGradient layout device dataType shape ->
  Tensor
    'WithoutGradient
    (layout <+> 'Layout 'Dense)
    (device <+> 'Device 'CPU)
    (Seq (dataType <+> 'DataType 'Int64) ('DataType 'Bool))
    (BroadcastShapesF shape ('Shape '[ 'Dim ('Name "*") ('Size 1)]))
mkRoBERTaPaddingMask = mkTransformerPaddingMask robertaPadTokenId

data RoBERTaInput input where
  RoBERTaInput ::
    forall input.
    { robertaInput :: input
    } ->
    RoBERTaInput input

deriving stock instance
  ( Show input
  ) =>
  Show (RoBERTaInput input)