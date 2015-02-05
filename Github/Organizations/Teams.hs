module Github.Organizations.Teams ( teamsForOrganization
                                  , membersForTeam
                                  , addToTeam
                                  , deleteFromTeam) where

import Github.Private
import Github.Data

type OrganizationName = String
type TeamName         = String
type GithubUser       = String
type TeamId           = Int

teamsForOrganization :: GithubAuth -> OrganizationName -> IO (Either Error [Team])
teamsForOrganization auth orgName = githubGet' (Just auth) ["orgs", orgName, "teams"]

membersForTeam :: GithubAuth -> TeamName -> IO (Either Error [GithubOwner])
membersForTeam auth teamIdent = githubGet' (Just auth) ["teams", show teamIdent, "members"]

addToTeam :: GithubAuth -> TeamId -> GithubUser -> IO (Either Error AddToTeamResponse)
addToTeam auth teamIdent githubUser = githubPut auth ["teams", show teamIdent, "memberships", githubUser]

deleteFromTeam :: GithubAuth -> TeamId -> GithubUser -> IO (Either Error DeleteResult)
deleteFromTeam auth teamIdent githubUser = githubDelete auth ["teams", show teamIdent, "memberships", githubUser]
