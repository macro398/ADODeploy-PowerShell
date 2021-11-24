## Pulling Token and Org from File ##

$ProvideAccess = get-content L:\ProvideAccess.txt|Out-String
$data = Invoke-Expression $ProvideAccess
$org = $data.Organization
$token = $data.Token

## Creating the Security Header##

# Requires the Organization name and a PAT #

$user = "PowerShell"
$pair = "${user}:${token}"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"

# Creates the header for the API call #

$header =@{
    Authorization = $basicAuthValue
    'Content-Type' = 'application/json'
    }

## Creating a new Project ##

# Gets the json file with the project name #
$file = get-childitem '.\*.json'|Get-Content

# URL for creating a new Project #
$url = 'https://dev.azure.com/' + $org + '/_apis/projects?api-version=4.1'

# Create the project and store the output in a variable #
Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $file

## Putting the name of the project into a variable for later use ##

$proj = ($file | ConvertFrom-Json).Name

## Wait some time for the project to get created ##
Start-Sleep -s 30

# TestPlan and TestSuite variables
$testplan = Get-content '.\TestPlan\*.json'

$testplanurl = 'https://dev.azure.com/'+ $org +'/'+ $proj +'/_apis/test/plans?api-version=5.0'


$tp = Invoke-RestMethod -Method Post -Uri $testplanurl -Headers $header -Body $testplan

$testsuiteurl = 'https://dev.azure.com/'+ $org +'/'+ $proj + '/_apis/test/Plans/' + $tp.id +'/suites/' + $tp.rootsuite.id +'?api-version=5.0'

## Creating all PBIs in a given folder ##
foreach($file in (get-childitem '.\PBIs\*.json'))
{
   $body = Get-Content -Path $file
   $header = @{
        Authorization = $basicAuthValue
        'Content-Type' = 'application/json-patch+json'
        }
   # Set Work Item Type #
   $workitemtype = 'product%20backlog%20item'
   
   # URL specific to creating Work Items used for both PBIs and Tasks #
   $url = 'https://dev.azure.com/' + $org + '/' + $proj +'/_apis/wit/workitems/$' + $workitemtype + '?api-version=4.1' 
   
   # Saves output per PBI #
   $apioutput = Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $body
   
   ## Saving PBI Name to a Folder URL ##
   
   # Gets the content of the Project Name \ PBI Name \ *.json #  
   $folder = ".\PBIs\" + $apioutput.fields.'System.Title' + "\*.json"
   $testfolder = ".\PBIs\" + $apioutput.fields.'System.Title' + "\tests\*.json"
   $tests = get-childitem $testfolder
   $contents = get-childitem $folder
   ## Creating all Tasks listed under the folder with the same name as the PBI ##
   if($contents){
   foreach($file in $contents)
    {
        $header = @{
            Authorization = $basicAuthValue
            'Content-Type' = 'application/json-patch+json'
        }
        
        # Sets Work Item Type to Task from PBI #
        $workitemtype = 'task'
        # Fixing URL to include correct work item type #
        $url = 'https://dev.azure.com/' + $org + '/' + $proj +'/_apis/wit/workitems/$' + $workitemtype + '?api-version=4.1' 
        ## Replace the $PBI$ variable out of the task json file ##
        $findString = '$PBI$'
        $replaceString = $apioutput.url
        $body = (Get-Content -Path $file) | foreach {$_.replace($findString,$replaceString)}
        
        ## Create the tasks as the child of the PBI ##
        Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $body 
    }
    if($tests){
   foreach($file in $tests)
    {
        $header = @{
            Authorization = $basicAuthValue
            'Content-Type' = 'application/json-patch+json'
        }
        
        # Sets Work Item Type to Task from PBI #
        $workitemtype = 'test%20case'
        # Fixing URL to include correct work item type #
        $url = 'https://dev.azure.com/' + $org + '/' + $proj +'/_apis/wit/workitems/$' + $workitemtype + '?api-version=4.1' 
        ## Replace the $PBI$ variable out of the task json file ##
        $findString = '$PBI$'
        $replaceString = $apioutput.url
        $body = (Get-Content -Path $file) | foreach {$_.replace($findString,$replaceString)}
        
        ## Create the tasks as the child of the PBI ##
        Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $body 
    }
    }
    foreach($testsuite in (get-childitem (".\PBIs\" + $apioutput.fields.'System.Title' + "\testsuite\*.json")))
    {
        $findString = '$PBI$'
        $replaceString = $apioutput.id
        $body = (Get-Content -Path $testsuite) | foreach {$_.replace($findString,$replaceString)}
   
        $header = @{
            Authorization = $basicAuthValue
            'Content-Type' = 'application/json'
            }
   
   Invoke-RestMethod -Method Post -Uri $testsuiteurl -Headers $header -Body $body
   }
    }
}

 ## Waiting 6 seconds to let things finish provisioning ##
    Start-Sleep -Seconds 6

    ## Variables for updating ##
    $directory = '.\Updates\*.json'

    $header = @{
        Authorization = $basicAuthValue
        'Content-Type' = 'application/json'
        }
    ## Running the Query ##

# URL for Running a Query #
$url = "https://dev.azure.com/" + $org + "/" + $proj + "/_apis/wit/wiql?api-version=4.1"

# File Containing Query #
$body = get-content '.\Query.txt'

# Running the Query and saving the output into variable #
$workitemIDs = Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $body

## Getting the details for the ID's returned by the query ##

# Creating an empty aray to store the details #
$AllWorkItems = @()

# Doing a request for each work item ID returned by the query #
Foreach($id in ($workitemIDs.workItems|select id))
{
    $url = "https://dev.azure.com/" + $org + "/" + $proj + "/_apis/wit/workitems/" + $id.id + "?api-version=4.1"

    $workitem = Invoke-RestMethod -Method Get -Uri $url -Headers $header
    $AllWorkItems += $workitem
}


## Start updating Items ##

# For each file in the $directory Update the specified work item based on basename #

foreach($file in (get-childitem $directory ))
    {
   
    # Matching the $file.basename object to the returned work items to get the ID #
    $match = $AllWorkItems | Select id, @{L='system.title'; E={$_.Fields.'System.Title'}} | where system.title -eq $file.BaseName

    # Creating variables for our API call #
    $url = "https://dev.azure.com/" + $org + "/_apis/wit/workitems/" + $match.id + "?api-version=4.1"
    $body = get-content $file
    
    # Change the content-type to application/json-patch+json #
    $header = @{
            Authorization = $basicAuthValue
            'Content-Type' = 'application/json-patch+json'
        }

    # Calling the API to do the greatest of things #
    Invoke-RestMethod -Method patch -Uri $url -Headers $header -Body $body

    }