{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
module Main (main) where

import           Control.Monad
import qualified Data.ByteString.Char8 as BS
import           Data.Default
import           Intro
import qualified Network.Connection as N
import qualified Network.HTTP.Client as HC
import qualified Network.HTTP.Client.TLS as HC
import qualified Network.HTTP.Proxy as P
import qualified Network.TLS as TLS
import qualified Network.TLS.Extra.Cipher as TLS
import qualified Network.Wai.Handler.Warp as Warp
import           Options.Applicative
import           Prelude (error)

main :: IO ()
main = do
  cfg <- execParser argParser
  creds <- case (cCert cfg, cKey cfg) of
             (Just cert, Just key) -> either error Just `fmap` TLS.credentialLoadX509 cert key
             _otherwise            -> pure Nothing
  let hooks = (\x -> if cInsecure cfg
                     then x { TLS.onServerCertificate = \_ _ _ _ -> return [] }
                     else x)
              $ (\x -> if isJust creds
                       then x { TLS.onCertificateRequest = \_ -> return creds }
                       else x)
              $ def
      tlsSettings = N.TLSSettings $ (TLS.defaultParamsClient "TODO"  "")
                    { TLS.clientHooks = hooks
                    , TLS.clientSupported = def { TLS.supportedCiphers = TLS.ciphersuite_default }
                    }

  mgr <- HC.newManager $ HC.mkManagerSettings tlsSettings Nothing
  -- P.runProxy (cPort cfg)
  let set = P.defaultProxySettings { P.proxyPort = (cPort cfg)
                                   , P.proxyHttpRequestModifier = if cVerbosity cfg > 0
                                                                  then \a -> print a >> pure (Right a)
                                                                  else pure . Right
                                   , P.proxyLogger = if cVerbosity cfg > 0
                                                     then BS.putStrLn
                                                     else const $ pure ()
                                   }
  Warp.runSettings (P.warpSettings set) $ P.httpProxyApp set mgr
  where
    argParser = info (cfgParser <**> helper)
                ( fullDesc
                  <> progDesc "Proxy that let you inspect the traffic"
                  <> header "mitmproxy - man in the middle proxy" )


data Config = Config
  { cPort :: Int
  , cInsecure :: Bool
  , cCert :: Maybe FilePath
  , cKey :: Maybe FilePath
  , cVerbosity :: Int
  }


cfgParser :: Parser Config
cfgParser = Config
  <$> option auto (short 'p'
                   <> long "port"
                   <> metavar "PORT"
                   <> help "The port to listen on (default: 8080)."
                   <> value 8080)
  <*> switch (long "insecure"
              <> help "Don't check the server certificate (insecure).")
  <*> optional (strOption (short 'c'
                 <> long "cert"
                 <> metavar "CERT_FILE"
                 <> help "The client certificate file."))
  <*> optional (strOption (short 'k'
                 <> long "key"
                 <> metavar "KEY_FILE"
                 <> help "The key file of the client certificate."))
  <*> (length <$> many v)
  where
    v = flag' () (short 'v'
                  <> long "verbose"
                  <> help "Be more verbose (multiple -v increase verbosity even more)."
                 )
