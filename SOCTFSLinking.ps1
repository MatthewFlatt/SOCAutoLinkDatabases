# Powershell script to hook up databases to SQL Source Control.
#
# Currently only for Shared-mode databases and TFS.
# Needs to be run on the SSMS client machine, with SQL Source Control already installed, logged in with the correct user.
# Requires Microsoft Visual Studio Team Foundation Server Power Tools to be installed.
# It will overwrite any existing config, so any current database links will be lost.

# Currently hard-coded to version 4.
$socPath = $env:LOCALAPPDATA + "\Red Gate\SQL Source Control 4\"

# Change this to the location of your master LinkedDatabases.xml file
[xml]$linkedDatabases = Get-Content C:\Temp\LinkedDatabases.xml 

# Get the list of all databases linked to TFS in the master xml file
$databaseNodes = $linkedDatabases.LinkedDatabaseStore.LinkedDatabaseList.value | where {$_.ISrcCLocation.type -eq 'TfsLocation'}

# Recreate the linking on the local machine
foreach ($linkedDatabase in $databaseNodes) 
{
        $tfs = get-tfs($linkedDatabase.ISrcCLocation.ServerUrl)
        $tfs.Authenticate()

	# Set a SQL Source Control workspace
        $randomFileName = [System.IO.Path]::GetRandomFileName()
        $randomDirectoryName = Join-Path (Join-Path $socPath WorkingBases) $randomFileName
        $workspace = $tfs.VCS.CreateWorkspace("SQL Source Control (" + $randomFileName + ")", $tfs.AuthenticatedUserName, "Used by SQL Source Control - do not modify")
        New-Item $randomDirectoryName -type Directory
        $workspace.Map($linkedDatabase.ISrcCLocation.SourceControlFolder, $randomDirectoryName)
        $workspace.Get()
        $node = $linkedDatabase.IWorkspaceId
        $node.RootPath = $randomDirectoryName.ToString()
    
	# Set a SQL Source Control location for transient files
        $randomFileName = [System.IO.Path]::GetRandomFileName()
        $randomDirectoryName = Join-Path (Join-Path $socPath Transients) $randomFileName
        $workspace = $tfs.VCS.CreateWorkspace("SQL Source Control (" + $randomFileName + ")", $tfs.AuthenticatedUserName, "Used by SQL Source Control - do not modify")
        New-Item $randomDirectoryName -type Directory  
        $workspace.Map($linkedDatabase.ISrcCLocation.SourceControlFolder, $randomDirectoryName)
        $workspace.Get() 
        $node = $linkedDatabase.ScriptTransientId
        $node.RootPath = $randomDirectoryName.ToString()       
}
$tempPath = Join-Path $socPath LinkedDatabases.xml
$linkedDatabases.Save($tempPath)


function get-tfs (
    [string] $serverName = $(Throw 'serverName is required')
)
{

    # load the required dll
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")

    $propertiesToAdd = (
        ('VCS', 'Microsoft.TeamFoundation.VersionControl.Client', 'Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer'),
        ('WIT', 'Microsoft.TeamFoundation.WorkItemTracking.Client', 'Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore'),
        ('BS', 'Microsoft.TeamFoundation.Build.Common', 'Microsoft.TeamFoundation.Build.Proxy.BuildStore'),
        ('CSS', 'Microsoft.TeamFoundation', 'Microsoft.TeamFoundation.Server.ICommonStructureService'),
        ('GSS', 'Microsoft.TeamFoundation', 'Microsoft.TeamFoundation.Server.IGroupSecurityService')
    )

   

    # fetch the TFS instance, but add some useful properties to make life easier
    # Make sure to "promote" it to a psobject now to make later modification easier
    [psobject] $tfs = [Microsoft.TeamFoundation.Client.TeamFoundationServerFactory]::GetServer($serverName)
    foreach ($entry in $propertiesToAdd) {
        $scriptBlock = '
            [System.Reflection.Assembly]::LoadWithPartialName("{0}") > $null
            $this.GetService([{1}])
        ' -f $entry[1],$entry[2]
        $tfs | add-member scriptproperty $entry[0] $ExecutionContext.InvokeCommand.NewScriptBlock($scriptBlock)
    }
    return $tfs
}
