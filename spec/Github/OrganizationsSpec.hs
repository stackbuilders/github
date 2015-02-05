module Github.OrganizationsSpec where

import Github.Organizations(publicOrganizationsFor, publicOrganization)
import Github.Organizations.Members (membersOf)
import Github.Data.Definitions (SimpleOrganization(..), Organization(..), GithubOwner(..))

import Test.Hspec (it, describe, shouldBe, shouldContain, Spec)

import Data.Either (isRight)

fromRight :: Either a b -> b
fromRight (Right b) = b
fromRight (Left _) = error "Expected a Right and got a Left"

--TODO: use changes in the API to reflect change in a state
spec :: Spec
spec = do
  describe "publicOrganizationsFor" $ do
    it "returns a list with the simple information about the user's organizations" $ do
      organizations <- publicOrganizationsFor "mike-burns"
      isRight organizations `shouldBe` True
      let firstOrg = simpleOrganizationLogin $ head $ fromRight organizations
      members <- membersOf firstOrg
      isRight members `shouldBe` True
      let namesFromMembers = map githubOwnerLogin (fromRight members)
      namesFromMembers `shouldContain` ["mike-burns"]

  describe "publicOrganization" $ do
    it "returns an Organization data for a organzation sent, with public permissions" $ do
      organization <- publicOrganization "stackbuilders"
      organizationLogin (fromRight organization) `shouldBe` "stackbuilders"
