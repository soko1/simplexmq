{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns #-}

module Simplex.Messaging.Server.QueueStore where

import Simplex.Messaging.Protocol
import Simplex.Messaging.Types

data QueueRec = QueueRec
  { recipientId :: QueueId,
    senderId :: QueueId,
    recipientKey :: PublicKey,
    senderKey :: Maybe PublicKey,
    status :: QueueStatus
  }

data QueueStatus = QueueActive | QueueOff

class MonadQueueStore s m where
  addQueue :: s -> RecipientKey -> (RecipientId, SenderId) -> m (Either ErrorType ())
  getQueue :: s -> SParty (a :: Party) -> QueueId -> m (Either ErrorType QueueRec)
  secureQueue :: s -> RecipientId -> SenderKey -> m (Either ErrorType ())
  suspendQueue :: s -> RecipientId -> m (Either ErrorType ())
  deleteQueue :: s -> RecipientId -> m (Either ErrorType ())

mkQueueRec :: RecipientKey -> (RecipientId, SenderId) -> QueueRec
mkQueueRec recipientKey (recipientId, senderId) =
  QueueRec
    { recipientId,
      senderId,
      recipientKey,
      senderKey = Nothing,
      status = QueueActive
    }