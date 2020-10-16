{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -fno-warn-unticked-promoted-constructors #-}

module Transmission where

import qualified Data.ByteString.Char8 as B
import Data.Singletons.TH
import Data.Time.Clock
import Data.Time.ISO8601
import Text.Read

$( singletons
     [d|
       data Party = Broker | Recipient | Sender
         deriving (Show)
       |]
 )

data Cmd where
  Cmd :: Sing a -> Command a -> Cmd

deriving instance Show Cmd

type Signed = (ConnId, Cmd)

type Transmission = (Signature, Signed)

type SignedOrError = (ConnId, Either ErrorType Cmd)

type TransmissionOrError = (Signature, SignedOrError)

type RawTransmission = (String, String, String)

data Command (a :: Party) where
  CONN :: RecipientKey -> Command Recipient
  SUB :: Command Recipient
  KEY :: SenderKey -> Command Recipient
  ACK :: Command Recipient
  OFF :: Command Recipient
  DEL :: Command Recipient
  SEND :: MsgBody -> Command Sender
  IDS :: RecipientId -> SenderId -> Command Broker
  MSG :: MsgId -> UTCTime -> MsgBody -> Command Broker
  END :: Command Broker
  OK :: Command Broker
  ERR :: ErrorType -> Command Broker

deriving instance Show (Command a)

deriving instance Eq (Command a)

parseCommand :: String -> Either ErrorType Cmd
parseCommand command = case words command of
  ["CONN", recipientKey] -> rCmd $ CONN recipientKey
  ["SUB"] -> rCmd SUB
  ["KEY", senderKey] -> rCmd $ KEY senderKey
  ["ACK"] -> rCmd ACK
  ["OFF"] -> rCmd OFF
  ["DEL"] -> rCmd DEL
  ["SEND"] -> errParams
  "SEND" : msgBody -> Right . Cmd SSender . SEND . B.pack $ unwords msgBody
  ["IDS", rId, sId] -> bCmd $ IDS rId sId
  ["MSG", msgId, ts, msgBody] -> case parseISO8601 ts of
    Just utc -> bCmd $ MSG msgId utc (B.pack msgBody)
    _ -> errParams
  ["END"] -> bCmd END
  ["OK"] -> bCmd OK
  "ERR" : err -> case err of
    ["UNKNOWN"] -> bErr UNKNOWN
    ["PROHIBITED"] -> bErr PROHIBITED
    ["SYNTAX", errCode] -> maybe errParams (bErr . SYNTAX) $ readMaybe errCode
    ["SIZE"] -> bErr SIZE
    ["AUTH"] -> bErr AUTH
    ["INTERNAL"] -> bErr INTERNAL
    _ -> errParams
  "CONN" : _ -> errParams
  "SUB" : _ -> errParams
  "KEY" : _ -> errParams
  "ACK" : _ -> errParams
  "OFF" : _ -> errParams
  "DEL" : _ -> errParams
  "MSG" : _ -> errParams
  "IDS" : _ -> errParams
  "END" : _ -> errParams
  "OK" : _ -> errParams
  _ -> Left UNKNOWN
  where
    errParams = Left $ SYNTAX errBadParameters
    rCmd = Right . Cmd SRecipient
    bCmd = Right . Cmd SBroker
    bErr = bCmd . ERR

serializeCommand :: Cmd -> String
serializeCommand = \case
  Cmd SRecipient (CONN rKey) -> "CONN " ++ rKey
  Cmd SRecipient (KEY sKey) -> "KEY " ++ sKey
  Cmd SRecipient cmd -> show cmd
  Cmd SSender (SEND msgBody) -> "SEND" ++ serializeMsg msgBody
  Cmd SBroker (MSG msgId ts msgBody) ->
    unwords ["MSG", msgId, formatISO8601Millis ts] ++ serializeMsg msgBody
  Cmd SBroker (IDS rId sId) -> unwords ["IDS", rId, sId]
  Cmd SBroker (ERR err) -> "ERR " ++ show err
  Cmd SBroker resp -> show resp
  where
    serializeMsg msgBody = " " ++ show (B.length msgBody) ++ "\n" ++ B.unpack msgBody

type Encoded = String

type PublicKey = Encoded

type Signature = Encoded

type RecipientKey = PublicKey

type SenderKey = PublicKey

type RecipientId = ConnId

type SenderId = ConnId

type ConnId = Encoded

type MsgId = Encoded

type MsgBody = B.ByteString

data ErrorType = UNKNOWN | PROHIBITED | SYNTAX Int | SIZE | AUTH | INTERNAL deriving (Show, Eq)

errBadParameters :: Int
errBadParameters = 2

errNoCredentials :: Int
errNoCredentials = 3

errHasCredentials :: Int
errHasCredentials = 4

errNoConnectionId :: Int
errNoConnectionId = 5

errMessageBody :: Int
errMessageBody = 6
