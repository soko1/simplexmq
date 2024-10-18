{-# LANGUAGE TemplateHaskell #-}

module Static.Embedded where

import Data.FileEmbed (embedDir, embedFile)
import Data.ByteString (ByteString)

indexHtml :: ByteString
indexHtml = $(embedFile "apps/xftp-server/static/index.html")

linkHtml :: ByteString
linkHtml = $(embedFile "apps/xftp-server/static/link.html")

mediaContent :: [(FilePath, ByteString)]
mediaContent = $(embedDir "apps/xftp-server/static/media/")
