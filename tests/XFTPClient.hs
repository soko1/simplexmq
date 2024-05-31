{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module XFTPClient where

import Control.Concurrent (ThreadId, threadDelay)
import Data.String (fromString)
import Network.Socket (ServiceName)
import SMPClient (serverBracket)
import Simplex.FileTransfer.Client
import Simplex.FileTransfer.Description
import Simplex.FileTransfer.Server (runXFTPServerBlocking)
import Simplex.FileTransfer.Server.Env (XFTPServerConfig (..), defaultFileExpiration, defaultInactiveClientExpiration, supportedXFTPhandshakes)
import Simplex.Messaging.Protocol (XFTPServer)
import Simplex.Messaging.Transport (ALPN)
import Simplex.Messaging.Transport.Server
import Test.Hspec

xftpTest :: HasCallStack => (HasCallStack => XFTPClient -> IO ()) -> Expectation
xftpTest test = runXFTPTest test `shouldReturn` ()

xftpTestN :: HasCallStack => Int -> (HasCallStack => [XFTPClient] -> IO ()) -> Expectation
xftpTestN n test = runXFTPTestN n test `shouldReturn` ()

xftpTest2 :: HasCallStack => (HasCallStack => XFTPClient -> XFTPClient -> IO ()) -> Expectation
xftpTest2 test = xftpTestN 2 _test
  where
    _test [h1, h2] = test h1 h2
    _test _ = error "expected 2 handles"

xftpTest4 :: HasCallStack => (HasCallStack => XFTPClient -> XFTPClient -> XFTPClient -> XFTPClient -> IO ()) -> Expectation
xftpTest4 test = xftpTestN 4 _test
  where
    _test [h1, h2, h3, h4] = test h1 h2 h3 h4
    _test _ = error "expected 4 handles"

runXFTPTest :: HasCallStack => (HasCallStack => XFTPClient -> IO a) -> IO a
runXFTPTest test = withXFTPServer $ testXFTPClient test

runXFTPTestN :: forall a. HasCallStack => Int -> (HasCallStack => [XFTPClient] -> IO a) -> IO a
runXFTPTestN nClients test = withXFTPServer $ run nClients []
  where
    run :: Int -> [XFTPClient] -> IO a
    run 0 hs = test hs
    run n hs = testXFTPClient $ \h -> run (n - 1) (h : hs)

withXFTPServerStoreLogOn :: HasCallStack => (HasCallStack => ThreadId -> IO a) -> IO a
withXFTPServerStoreLogOn = withXFTPServerCfg testXFTPServerConfig {storeLogFile = Just testXFTPLogFile, serverStatsBackupFile = Just testXFTPStatsBackupFile}

withXFTPServerCfg :: HasCallStack => XFTPServerConfig -> (HasCallStack => ThreadId -> IO a) -> IO a
withXFTPServerCfg cfg =
  serverBracket
    (`runXFTPServerBlocking` cfg)
    (threadDelay 10000)

withXFTPServerThreadOn :: HasCallStack => (HasCallStack => ThreadId -> IO a) -> IO a
withXFTPServerThreadOn = withXFTPServerCfg testXFTPServerConfig

withXFTPServer :: HasCallStack => IO a -> IO a
withXFTPServer = withXFTPServerCfg testXFTPServerConfig . const

withXFTPServer2 :: HasCallStack => IO a -> IO a
withXFTPServer2 = withXFTPServerCfg testXFTPServerConfig {xftpPort = xftpTestPort2, filesPath = xftpServerFiles2} . const

xftpTestPort :: ServiceName
xftpTestPort = "7000"

xftpTestPort2 :: ServiceName
xftpTestPort2 = "7001"

testXFTPServer :: XFTPServer
testXFTPServer = fromString testXFTPServerStr

testXFTPServer2 :: XFTPServer
testXFTPServer2 = fromString testXFTPServerStr2

testXFTPServerStr :: String
testXFTPServerStr = "xftp://LcJUMfVhwD8yxjAiSaDzzGF3-kLG4Uh0Fl_ZIjrRwjI=@localhost:7000"

testXFTPServerStr2 :: String
testXFTPServerStr2 = "xftp://LcJUMfVhwD8yxjAiSaDzzGF3-kLG4Uh0Fl_ZIjrRwjI=@localhost:7001"

xftpServerFiles :: FilePath
xftpServerFiles = "tests/tmp/xftp-server-files"

xftpServerFiles2 :: FilePath
xftpServerFiles2 = "tests/tmp/xftp-server-files2"

testXFTPLogFile :: FilePath
testXFTPLogFile = "tests/tmp/xftp-server-store.log"

testXFTPStatsBackupFile :: FilePath
testXFTPStatsBackupFile = "tests/tmp/xftp-server-stats.log"

testXFTPServerConfig :: XFTPServerConfig
testXFTPServerConfig = testXFTPServerConfig_ (Just supportedXFTPhandshakes)

testXFTPServerConfig_ :: Maybe [ALPN] -> XFTPServerConfig
testXFTPServerConfig_ alpn =
  XFTPServerConfig
    { xftpPort = xftpTestPort,
      controlPort = Nothing,
      fileIdSize = 16,
      storeLogFile = Nothing,
      filesPath = xftpServerFiles,
      fileSizeQuota = Nothing,
      allowedChunkSizes = [kb 64, kb 128, kb 256, mb 1, mb 4],
      allowNewFiles = True,
      newFileBasicAuth = Nothing,
      controlPortAdminAuth = Nothing,
      controlPortUserAuth = Nothing,
      fileExpiration = Just defaultFileExpiration,
      fileTimeout = 10000000,
      inactiveClientExpiration = Just defaultInactiveClientExpiration,
      caCertificateFile = "tests/fixtures/ca.crt",
      privateKeyFile = "tests/fixtures/server.key",
      certificateFile = "tests/fixtures/server.crt",
      logStatsInterval = Nothing,
      logStatsStartTime = 0,
      serverStatsLogFile = "tests/tmp/xftp-server-stats.daily.log",
      serverStatsBackupFile = Nothing,
      transportConfig = defaultTransportServerConfig {alpn},
      responseDelay = 0
    }

testXFTPClientConfig :: XFTPClientConfig
testXFTPClientConfig = defaultXFTPClientConfig

testXFTPClient :: HasCallStack => (HasCallStack => XFTPClient -> IO a) -> IO a
testXFTPClient = testXFTPClientWith testXFTPClientConfig

testXFTPClientWith :: HasCallStack => XFTPClientConfig -> (HasCallStack => XFTPClient -> IO a) -> IO a
testXFTPClientWith cfg client =
  getXFTPClient (1, testXFTPServer, Nothing) cfg (\_ -> pure ()) >>= \case
    Right c -> client c
    Left e -> error $ show e
