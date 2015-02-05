module Github.Organizations.MembersSpec where

import Github.Organizations.Members (membersOf)
import Github.Organizations(publicOrganizationsFor)
import Github.Data.Definitions (SimpleOrganization(..), GithubOwner(..))

import Test.Hspec (it, describe, shouldBe, shouldContain, Spec)

import Data.Either (isRight)

fromRight :: Either a b -> b
fromRight (Right b) = b
fromRight (Left _) = error "Expected a Right and got a Left"

spec :: Spec
spec =
  describe "membersOf" $ do
    it "returns a list of GithubOwners for an organization" $ do
      members <- membersOf "stackbuilders"
      isRight members `shouldBe` True
      let firstMember = githubOwnerLogin $ head $ fromRight members
      memberOrganizations <- publicOrganizationsFor firstMember
      isRight memberOrganizations `shouldBe` True
      let namesFromOrganizations = map simpleOrganizationLogin (fromRight memberOrganizations)
      namesFromOrganizations `shouldContain` ["stackbuilders"]
