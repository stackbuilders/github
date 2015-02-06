Github
------
[![Build Status](https://travis-ci.org/stackbuilders/github.svg?branch=add_specs)](https://travis-ci.org/stackbuilders/github)

The Github API v3 for Haskell.

Some functions are missing; these are functions where the Github API did
not work as expected. The full Github API is in beta and constantly
improving.

Installation
============

In your project's cabal file:

    -- Packages needed in order to build this package.
    Build-depends:       github

Or from the command line:

    cabal install github

Example Usage
=============

See the samples in the
[samples/](https://github.com/fpco/github/tree/master/samples) directory.

Documentation
=============

For details see the reference documentation on Hackage.

Each module lines up with the hierarchy of
[documentation from the Github API](http://developer.github.com/v3/).

Each function has a sample written for it.

All functions produce an `IO (Either Error a)`, where `a` is the actual thing
you want. You must call the function using IO goodness, then dispatch on the
possible error message. Here's an example from the samples:

    import qualified Github.Users.Followers as Github
    import Data.List (intercalate)

    main = do
      possibleUsers <- Github.usersFollowing "mike-burns"
      putStrLn $ either (("Error: "++) . show)
                        (intercalate "\n" . map formatUser)
                        possibleUsers

    formatUser = Github.githubOwnerLogin

Contributions
=============

Please see
[CONTRIBUTING.md](https://github.com/fpco/github/blob/master/CONTRIBUTING.md)
for details on how you can help.

Copyright
=========

Copyright 2011, 2012 Mike Burns.
Copyright 2013-2014 John Wiegley.

Available under the BSD 3-clause license.
