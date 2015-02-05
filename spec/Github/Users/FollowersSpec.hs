module Github.Users.FollowersSpec where

import Github.Users.Followers (usersFollowedBy, usersFollowing)
import Github.Data.Definitions (GithubOwner(..), DeleteResult(..))
import Github.Data (Error)

import Test.Hspec (it, describe, shouldBe, shouldContain, Spec)
import Github.Private (githubPut, githubDelete, GithubAuth(..))
import Control.Applicative ((<$>))

import Data.Either (isRight)
import System.Posix.Env (getEnvDefault)

fromRight :: Either a b -> b
fromRight (Right b) = b
fromRight (Left _) = error "Expected a Right and got a Left"

--TODO: use changes in the API to reflect change in a state
spec :: Spec
spec = do
  describe "usersFollowedBy" $ do
    it "returns a list with the GithubOwners the user is following" $ do
      oAuth <- GithubOAuth <$> getEnvDefault "TESTS_TOKEN" ""
      follow <- followUser oAuth "mike-burns"
      isRight follow `shouldBe` True
      usersFollowed <- usersFollowedBy "testUserForGithub"
      isRight usersFollowed `shouldBe` True
      map githubOwnerLogin (fromRight usersFollowed) `shouldContain` ["mike-burns"]
  describe "usersFollowing" $ do
    it "returns a list with the GithubOwners that follow the user" $ do
      oAuth <- GithubOAuth <$> getEnvDefault "TESTS_TOKEN" ""
      follow <- followUser oAuth "mike-burns"
      isRight follow `shouldBe` True
      following <- usersFollowing "mike-burns"
      map githubOwnerLogin (fromRight following) `shouldContain` ["testUserForGithub"]

followUser :: GithubAuth -> String -> IO (Either Error ())
followUser auth user = githubPut auth ["user", "following", "mike-burns"]
