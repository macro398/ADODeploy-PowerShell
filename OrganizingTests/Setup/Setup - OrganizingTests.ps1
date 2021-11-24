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
    }
}
foreach($test in (get-childitem '.\Tests\*.json'))
{
   $body = Get-Content -Path $test
   $header = @{
        Authorization = $basicAuthValue
        'Content-Type' = 'application/json-patch+json'
        }
   # Set Work Item Type #
   $workitemtype = 'test%20case'
   
   # URL specific to creating Work Items used for both PBIs and Tasks #
   $url = 'https://dev.azure.com/' + $org + '/' + $proj +'/_apis/wit/workitems/$' + $workitemtype + '?api-version=4.1' 
   
   # Saves output per PBI #
   $apioutput = Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $body
   }