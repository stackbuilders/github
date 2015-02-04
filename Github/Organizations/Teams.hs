module Github.Organizations.Teams ( teamsForOrganization
                                  , membersForTeam) where

import Github.Private
import Github.Data

teamsForOrganization :: GithubAuth -> String -> IO (Either Error [Team])
teamsForOrganization auth orgName = githubGet' (Just auth) ["orgs", orgName, "teams"]

membersForTeam :: GithubAuth -> Int -> IO (Either Error [GithubOwner])
membersForTeam auth teamIdent = githubGet' (Just auth) ["teams", show teamIdent, "members"]
