# SOCAutoLinkDatabases
Scripts for customers to automatically link databases for many users.

A master LinkedDatabases.xml file must be produced by linking the required databases in SQL Source Control.

Currently works only for TFS and the Shared database model.

Needs to be run on the SSMS client machine, logged in with the user, with SQL Source Control installed.

Will overwrite any existing config so existing linked databases will be lost.

Requires Microsoft Visual Studio Team Foundation Server Power Tools and Team Explorer for Visual Studio 2013 to be installed.
