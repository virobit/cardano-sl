{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE Rank2Types       #-}
{-# LANGUAGE TemplateHaskell  #-}

-- @jens: this document is inspired by https://github.com/input-output-hk/rscoin-haskell/blob/master/src/RSCoin/Explorer/Storage.hs
module Pos.Wallet.Web.State.Storage
       (
         WalletStorage (..)
       , Query
       , Update
       , getWalletMetas
       , getWalletMeta
       , createWallet
       , setWalletMeta
       , setWalletHistory
       , getWalletHistory
       , addOnlyNewHistory
       , removeWallet
       ) where

import           Control.Lens               (at, ix, makeClassy, preview, view, (%=),
                                             (.=), _1, _2, _Just)
import           Data.Default               (Default, def)
import qualified Data.HashMap.Strict        as HM (elems, fromList, union)
import           Data.SafeCopy              (base, deriveSafeCopySimple)
import           Pos.Wallet.Web.ClientTypes (CAddress, CCurrency, CHash, CTxId, CTxMeta,
                                             CWalletMeta, CWalletType)
import           Universum

type TransactionHistory = HashMap CTxId CTxMeta

data WalletStorage = WalletStorage
    {
      _wsWalletMetas :: !(HashMap CAddress (CWalletMeta, TransactionHistory))
    }

makeClassy ''WalletStorage

instance Default WalletStorage where
    def =
        WalletStorage
        {
          _wsWalletMetas = mempty
        }

type Query a = forall m. (MonadReader WalletStorage m) => m a
type Update a = forall m. ({-MonadThrow m, -}MonadState WalletStorage m) => m a

getWalletMetas :: Query [CWalletMeta]
getWalletMetas = HM.elems . map fst <$> view wsWalletMetas

getWalletMeta :: CAddress -> Query (Maybe CWalletMeta)
getWalletMeta cAddr = preview (wsWalletMetas . ix cAddr . _1)

getWalletHistory :: CAddress -> Query (Maybe [CTxMeta])
getWalletHistory cAddr = fmap HM.elems <$> preview (wsWalletMetas . ix cAddr . _2)

createWallet :: CAddress -> CWalletMeta -> Update ()
createWallet cAddr wMeta = wsWalletMetas . at cAddr .= Just (wMeta, mempty)

setWalletMeta :: CAddress -> CWalletMeta -> Update ()
setWalletMeta cAddr wMeta = wsWalletMetas . at cAddr . _Just . _1 .= wMeta

addWalletHistoryTx :: CAddress -> CTxId -> CTxMeta -> Update ()
addWalletHistoryTx cAddr ctxId ctxMeta = wsWalletMetas . at cAddr . _Just . _2 . at ctxId .= Just ctxMeta

setWalletHistory :: CAddress -> [(CTxId, CTxMeta)] -> Update ()
setWalletHistory cAddr ctxs = () <$ mapM (uncurry $ addWalletHistoryTx cAddr) ctxs

-- FIXME: this will be removed later (temporary solution)
addOnlyNewHistory :: CAddress -> [(CTxId, CTxMeta)] -> Update ()
addOnlyNewHistory cAddr ctxs = wsWalletMetas . at cAddr . _Just . _2 %= HM.union (HM.fromList ctxs)

setWalletTransactionMeta :: CAddress -> CTxId -> CTxMeta -> Update ()
setWalletTransactionMeta cAddr ctxId ctxMeta = wsWalletMetas . at cAddr . _Just . _2 . at ctxId .= Just ctxMeta

removeWallet :: CAddress -> Update ()
removeWallet cAddr = wsWalletMetas . at cAddr .= Nothing

deriveSafeCopySimple 0 'base ''CHash
deriveSafeCopySimple 0 'base ''CAddress
deriveSafeCopySimple 0 'base ''CCurrency
deriveSafeCopySimple 0 'base ''CWalletType
deriveSafeCopySimple 0 'base ''CWalletMeta
deriveSafeCopySimple 0 'base ''CTxId
deriveSafeCopySimple 0 'base ''CTxMeta
deriveSafeCopySimple 0 'base ''WalletStorage
