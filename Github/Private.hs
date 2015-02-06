{-# LANGUAGE OverloadedStrings, StandaloneDeriving, DeriveDataTypeable, GADTs #-}
{-# LANGUAGE CPP #-}
module Github.Private where

import Github.Data
import Data.Aeson
import Data.Attoparsec.ByteString.Lazy
import Data.Data
import Data.Monoid
import Control.Applicative
import Data.List
import Data.CaseInsensitive (mk)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import Network.HTTP.Types (Status(..), notFound404)
import Network.HTTP.Conduit
-- import Data.Conduit (ResourceT)
import qualified Control.Exception as E
import Data.Maybe (fromMaybe)

-- | user/password for HTTP basic access authentication
data GithubAuth = GithubBasicAuth BS.ByteString BS.ByteString
                | GithubOAuth String
                deriving (Show, Data, Typeable, Eq, Ord)

githubGet :: (FromJSON b, Show b) => [String] -> IO (Either Error b)
githubGet = githubGet' Nothing

githubGet' :: (FromJSON b, Show b) => Maybe GithubAuth -> [String] -> IO (Either Error b)
githubGet' auth paths =
  githubAPI (BS.pack "GET")
            (buildUrl paths)
            auth
            (Nothing :: Maybe Value)

githubGetWithQueryString :: (FromJSON b, Show b) => [String] -> String -> IO (Either Error b)
githubGetWithQueryString = githubGetWithQueryString' Nothing

githubGetWithQueryString' :: (FromJSON b, Show b) => Maybe GithubAuth -> [String] -> String -> IO (Either Error b)
githubGetWithQueryString' auth paths qs =
  githubAPI (BS.pack "GET")
            (buildUrl paths ++ "?" ++ qs)
            auth
            (Nothing :: Maybe Value)

githubPost :: (ToJSON a, Show a, FromJSON b, Show b) => GithubAuth -> [String] -> a -> IO (Either Error b)
githubPost auth paths body =
  githubAPI (BS.pack "POST")
            (buildUrl paths)
            (Just auth)
            (Just body)

githubPatch :: (ToJSON a, Show a, FromJSON b, Show b) => GithubAuth -> [String] -> a -> IO (Either Error b)
githubPatch auth paths body =
  githubAPI (BS.pack "PATCH")
            (buildUrl paths)
            (Just auth)
            (Just body)

githubPut :: (FromJSON b, Show b) => GithubAuth -> [String] -> IO (Either Error b)
githubPut auth paths =
  githubAPI (BS.pack "PUT")
            (buildUrl paths)
            (Just auth)
            (Nothing :: Maybe Value)

githubDelete :: (FromJSON b, Show b, b ~ DeleteResult) => GithubAuth -> [String] -> IO (Either Error DeleteResult)
githubDelete auth paths =
  githubAPI (BS.pack "DELETE")
            (buildUrl paths)
            (Just auth)
            (Nothing :: Maybe Value)

buildUrl :: [String] -> String
buildUrl paths = "https://api.github.com/" ++ intercalate "/" paths

githubAPI :: (ToJSON a, Show a, FromJSON b, Show b) => BS.ByteString -> String
          -> Maybe GithubAuth -> Maybe a -> IO (Either Error b)
githubAPI apimethod url auth body = do
  result <- doHttps apimethod url auth (encodeBody body)
  case result of
      Left e     -> return (Left (HTTPConnectionError e))
      Right resp -> either Left (\x -> jsonResultToE (LBS.pack (show x))
                                                   (fromJSON x))
                          <$> handleBody resp

  where
    encodeBody = Just . RequestBodyLBS . encode . toJSON

    handleBody resp = either (return . Left) (handleJson resp)
                             (parseJsonRaw (responseBody resp))

    -- This is an "escaping" version of "for", which returns (Right esc) if
    -- the value 'v' is Nothing; otherwise, it extracts the value from the
    -- Maybe, applies f, and return an IO (Either Error b).
    forE :: b -> Maybe a -> (a -> IO (Either Error b))
         -> IO (Either Error b)
    forE = flip . maybe . return . Right

    handleJson resp gotjson@(Array ary) =
        -- Determine whether the output was paginated, and if so, we must
        -- recurse to obtain the subsequent pages, and append those result
        -- bodies to the current one.  The aggregate will then be parsed.
        forE gotjson (lookup "Link" (responseHeaders resp)) $ \l ->
            forE gotjson (getNextUrl (BS.unpack l)) $ \nu ->
                either (return . Left . HTTPConnectionError)
                       (\nextResp -> do
                             nextJson <- handleBody nextResp
                             return $ (\(Array x) -> Array (ary <> x))
                                          <$> nextJson)
                       =<< doHttps apimethod nu auth Nothing
    handleJson _ gotjson = return (Right gotjson)

    getNextUrl l =
        if "rel=\"next\"" `isInfixOf` l
        then let s  = l
                 s' = Data.List.tail $ Data.List.dropWhile (/= '<') s
             in Just (Data.List.takeWhile (/= '>') s')
        else Nothing

doHttps :: BS.ByteString
           -> [Char]
           -> Maybe GithubAuth
           -> Maybe RequestBody
           -> IO (Either E.SomeException (Response LBS.ByteString))
doHttps reqMethod url auth body = do
  let reqBody = fromMaybe (RequestBodyBS $ BS.pack "") body
      reqHeaders = maybe [] getOAuth auth
      Just uri = parseUrl url
      request = uri { method = reqMethod
                    , secure = True
                    , port = 443
                    , requestBody = reqBody
                    , responseTimeout = Just 20000000
                    , requestHeaders = reqHeaders <>
                                       [("User-Agent", "github.hs/0.7.4")]
                                       <> [("Accept", "application/vnd.github.preview")]
                    , checkStatus = successOrMissing
                    }
      authRequest = getAuthRequest auth request

  (getResponse authRequest >>= return . Right) `E.catches` [
      -- Re-throw AsyncException, otherwise execution will not terminate on
      -- SIGINT (ctrl-c).  All AsyncExceptions are re-thrown (not just
      -- UserInterrupt) because all of them indicate severe conditions and
      -- should not occur during normal operation.
      E.Handler (\e -> E.throw (e :: E.AsyncException)),
      E.Handler (\e -> (return . Left) (e :: E.SomeException))
      ]
  where
    getAuthRequest (Just (GithubBasicAuth user pass)) = applyBasicAuth user pass
    getAuthRequest _ = id
    getOAuth (GithubOAuth token) = [(mk (BS.pack "Authorization"),
                                     BS.pack ("token " ++ token))]
    getOAuth _ = []
    getReply request = withManager $ \manager -> httpLbs request manager
    getResponse = ensureBodyContents `dmap` getReply
#if MIN_VERSION_http_conduit(1, 9, 0)
    successOrMissing s@(Status sci _) hs cookiejar
#else
    successOrMissing s@(Status sci _) hs
#endif
      | (200 <= sci && sci < 300) || sci == 404 = Nothing
#if MIN_VERSION_http_conduit(1, 9, 0)
      | otherwise = Just $ E.toException $ StatusCodeException s hs cookiejar
#else
      | otherwise = Just $ E.toException $ StatusCodeException s hs
#endif

doHttpsStatus :: BS.ByteString -> String -> GithubAuth -> Maybe RequestBody -> IO (Either Error Status)
doHttpsStatus reqMethod url auth payload = do
  result <- doHttps reqMethod url (Just auth) payload
  case result of
    Left e -> return (Left (HTTPConnectionError e))
    Right resp ->
      let status = responseStatus resp
          headers = responseHeaders resp
      in if status == notFound404
            -- doHttps silently absorbs 404 errors, but for this operation
            -- we want the user to know if they've tried to delete a
            -- non-existent repository
         then return (Left (HTTPConnectionError
                            (E.toException
                             (StatusCodeException status headers
#if MIN_VERSION_http_conduit(1, 9, 0)
                                 (responseCookieJar resp)
#endif
                                 ))))
             else return (Right status)

parseJsonRaw :: LBS.ByteString -> Either Error Value
parseJsonRaw jsonString =
  let parsed = parse json jsonString in
  case parsed of
       Data.Attoparsec.ByteString.Lazy.Done _ jsonResult -> Right jsonResult
       (Fail _ _ e) -> Left $ ParseError e

jsonResultToE :: Show b => LBS.ByteString -> Data.Aeson.Result b
              -> Either Error b
jsonResultToE jsonString result = case result of
    Success s -> Right s
    Error e   -> Left $ JsonError $
                 e ++ " on the JSON: " ++ LBS.unpack jsonString

parseJson :: (FromJSON b, Show b) => LBS.ByteString -> Either Error b
parseJson jsonString = either Left (jsonResultToE jsonString . fromJSON)
                              (parseJsonRaw jsonString)


dmap :: (Functor f, Functor g) => (a -> b) -> f (g a) -> f (g b)
dmap = fmap . fmap

ensureBodyContents :: Response LBS.ByteString -> Response LBS.ByteString
ensureBodyContents resp
  | (responseBody resp) /= "" = resp
  | otherwise = resp { responseBody = "[]" }
