!/bin/bash
#set -x

############################################################################################
##
## Shell script to Download shell scripts from Intune
##
###########################################

###########################################################################################
## Script Name	:   Get-deviceShellScripts.sh
## Author       :   Steffen Greve
##
## To obtain a client id, go to portal.azure.com and click on "App registration"
## Press " + New registration
## Give the application a name
## Select "Accounts in this organizational directory only (XXXXXXX only - Single tenant)
## Press "Registrer"
##
## Go to "Api Permissions" and press " + Add Permission" and select those needed. Then "Grant consent for domain"
## Go to "Certification & Secrets" and press " + New client secret". Type in a description and select 24 months.
## Copy Secret "Value", and go to Overview and copy "Application Id" and fill in Tenantname also in below variables.
##
###########################################

clientId="<APPLICATIONID>"
clientSecret="<CLIENTSECRET>"
tenantName="XXXXXXX.onmicrosoft.com"
exportDir="/paht/to/exported/scripts"

# function to get auth token from graph api with cUrl
function Get-AuthToken() {
    : '
    .SYNOPSIS
    Get Auth token for access to Microsoft Graph Api
    
    .DESCRIPTION
    The Get-AuthToken cmdlet connects to Microsoft Graph Api with ClientId, ClientSecret and Tenant name.
    Initial Author: Steffen Greve (atea.dk)
    The script is provided "AS IS" with no warrenties.
    
    .PARAMETER ClientId
    The application id is from the Azure AD Application registration.
    .PARAMENTER ClientSecret
    The client secret created within the above application.
    .PARAMETER TenantName
    The tenant domain name xxxx.onmicrosoft.com
    '
    ClientId=$1
    ClientSecret=$2
    TenantName=$3
    JQ=$4
    
    tokenResult=$(curl -sf -X "POST" "https://login.microsoftonline.com/$TenantName/oauth2/token" \
    -H 'Content-Type: application/x-www-form-urlencoded; charset=utf-8' \
    --data-urlencode "client_id=$ClientId" \
    --data-urlencode "client_secret=$ClientSecret" \
    --data-urlencode "Resource=https://graph.microsoft.com/" \
    --data-urlencode "grant_type=client_credentials")
    
    if [[ JQ ]]; then
        accessToken=$(echo "${tokenResult}" | jq -r '.access_token')
    else
        accessToken=$(echo "${tokenResult}" | grep -Eo '"access_token"[^,]*' | grep -Eo '[^:]*$' | egrep -o '^[^}]+' | tr -d '"')
    fi        
    echo "$accessToken"
}

function Get-DeviceShellScripts() {
    : '
    .SYNOPSIS
    Get all Intune Shell scripts and save them in specified folder.
    
    .DESCRIPTION
    The Get-DeviceShellScripts cmdlet downloads all Shell scripts from Intune to a specified folder.
    Initial Author: Steffen Greve (atea.dk)
    The script is provided "AS IS" with no warranties.
    
    .PARAMETER AccessToken
    The Access Token to communicate with Graph Api
    .PARAMETER FolderPath
    The folder where the script(s) are saved.
    .EXAMPLE
    Download all Intune Shell scripts to the specified folder
    Get-DeviceShellScripts $accessToken .\ShellScripts 
    '
    AccessToken=$1
    FolderPath=$2
    JQ=$3
    
    mkdir -p $FolderPath
    
    header='Content-Type: application/x-www-form-urlencoded; charset=utf-8'
    graphApiVersion="Beta"
    graphUrl="https://graph.microsoft.com/$graphApiVersion"

    if [[ JQ ]]; then
        results=$(curl -sf "$graphUrl/deviceManagement/deviceShellScripts" -H "Authorization: Bearer ${AccessToken}" -H $header | jq -r '.value[] | .id' )
        shellScripts=($results)
        for (( i=0; i<${#shellScripts[@]}; i++ )); do
            shellScriptInfo=$(curl -sf "$graphUrl/deviceManagement/deviceShellScripts/${shellScripts[$i]}" -H "Authorization: Bearer ${AccessToken}" -H $header)
            displayName=$(echo "${shellScriptInfo}" | jq -r '. | .displayName')
            fileName=$(echo "${shellScriptInfo}" | jq -r '. | .fileName')
            scriptContent=$(echo "${shellScriptInfo}" | jq -r '. | .scriptContent' | base64 -D)
            echo "Exporting $displayName to $FolderPath/$fileName"
            echo "$scriptContent" > "$FolderPath/$fileName"
        done
    else
        IFS=$'\n'
        results=$(curl -sf "$graphUrl/deviceManagement/deviceShellScripts" -H "Authorization: Bearer ${AccessToken}" -H $header | grep -Eo '"id"[^,]*' | grep -Eo '[^:]*$' | tr -d '"')
        shellScripts=($results)
        while IFS= read -r id; do
            shellScriptInfo=$(curl -sf "$graphUrl/deviceManagement/deviceShellScripts/$id" -H "Authorization: Bearer ${AccessToken}" -H $header)
            displayName=$(echo "${shellScriptInfo}" | grep -Eo '"displayName"[^,]*' | grep -Eo '[^:]*$' | tr -d '"')
            fileName=$(echo "${shellScriptInfo}" | grep -Eo '"fileName"[^,]*' | grep -Eo '[^:]*$' | tr -d '"')
            scriptContent=$(echo "${shellScriptInfo}" | grep -Eo '"scriptContent"[^,]*' | grep -Eo '[^:]*$' | tr -d '"' | base64 -D)
            echo "Exporting $displayName to $FolderPath/$fileName"
            echo "$scriptContent" > "$FolderPath/$fileName"
        done <<< "$shellScripts"
    fi
}

if command -v jq &> /dev/null; then
    echo "Exporting data with jq"
    jq=$true
else
    echo "Exporting data without jq using grep"
    jq=$false
fi

accessToken=$(Get-AuthToken $clientId $clientSecret $tenantName $jq)
Get-DeviceShellScripts $accessToken $exportDir $jq


        