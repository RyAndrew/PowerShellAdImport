<#
 Update: version 1.1 added splatting

Okta Version 1.2, see VersionHistory.txt

Just add fisrtname, lastname in the csv and place on C:\ as users.csv
Example:-

                            ******** ##### ********
                                   FirstName,lastName
                                   George,Bush
                                   Thomas,Edison
                                   Britney,Spears
                            ******** ##### ********

--> Here are examples of samaccountname or username comment out rest which does'nt suit your organistation and keep the required one.

    $SAM = $user.FirstName.Substring(0,1) + $user.LastName #example John snow will be Jsnow
    #$Sam=$User.FirstName+$User.LastName example john snow will be Johnsnow
    #$Sam=$User.FirstName example john snow will be John
    #$Sam=$User.firstName + "." + $User.lastName example john snow will be John.snow
    #$Sam=$user.Lastname+$user.Firstname.Substring(0,1) example john snow will be sjohn

#>
If (!(Get-module ActiveDirectory )) {
  Import-Module ActiveDirectory
  Clear-Host
  }

$filename=$args[0];

$Users=Import-csv $filename;
$a=1;
$b=1;
$rootDomain='DC=' + $(Get-ADDomainController -Discover).Domain.Replace('.',',DC=');
$failedUsers = @()
$successUsers = @()
$VerbosePreference = "Continue"
$ErrorActionPreference='stop'
$LogFolder = "$env:userprofile\desktop\logs"

$Orgs = "Employees","Interns","Partners"
foreach ($Org in $Orgs) {
Try {
   New-ADOrganizationalUnit -Name "$Org"
}
Catch {
   Write-Verbose "OU=$Org already exists"
}
}


 ForEach($User in $Users)
   {
   $FirstName = $User.FirstName.substring(0,1).toupper()+$User.FirstName.substring(1).tolower()
   $LastName  = $User.LastName.substring(0,1).toupper()+$User.LastName.substring(1).tolower()

   $FullName = $User.FirstName + " " + $User.LastName
   $Organization = "Okta Ice"
   
   $groups = $User.Groups -split ';'
   foreach ($group in $groups) {
		if ( !($group -eq "")) {
			try {
				$exgroup=Get-ADGroup -Identity "$group";
			}
			catch {
				echo "Creating group: $group";
				$path="OU=employees,"+$rootDomain
				New-ADGroup -Name "$group" -GroupScope "Global" -Path $path;
			}
		}
	}

   $SAM = $User.firstName + "." + $User.lastName
   <#
   $Sam=$User.FirstName+$User.LastName --> example john snow will be Johnsnow
   $Sam=$User.FirstName --> example john snow will be John
   $Sam= $User.firstName + "." + $User.lastName  --> example john snow will be John.snow
   $Sam=$user.Lastname+$user.Firstname.Substring(0,1))  --> example john snow will be sjohn
   #>

   $dnsroot = '@' + (Get-ADDomain).dnsroot

   $SAM=$sam.tolower()

   # To set Diffreent Passwords for each User add header Password on CSV and change 'P@ssw0rd@123' to $user.passsword
   $Password = (ConvertTo-SecureString -AsPlainText 'Tra!nme4321' -Force)


   $UPN=$User.email # change "$dnsroot to custom domain if you want, by default it will take from DNS ROOT"

   $OU=$User.OU+","+$rootDomain # Choose an Ou where users will be created # Running cmd will show all OU's Get-ADOrganizationalUnit -Filter * | Select-Object -Property DistinguishedName| Out-GridView -PassThru| Select-Object -ExpandProperty DistinguishedName

   $email=$User.email # change "$dnsroot to custom domain if you want, by default it will take from DNS ROOT"

$Title=$User.Title
$Phone=$User.Phone
$Dept=$User.Department


Try {
    if (!(get-aduser -Filter {samaccountname -eq "$SAM"})){
     $Parameters = @{
    'SamAccountName'        = $SAM
    'UserPrincipalName'     = $UPN
    'Name'                  = $Fullname
    'EmailAddress'          = $Email
    'GivenName'             = $FirstName
    'Surname'               = $Lastname
    'OfficePhone'           = $Phone
    'Title'                 = $Title
    'Department'            = $Dept
    'Organization'          = $Organization
    'AccountPassword'       = $password
    'ChangePasswordAtLogon' = $false
    'Enabled'               = $true
    'Path'                  = $OU
    'PasswordNeverExpires'  = $true
}

New-ADUser @Parameters
     Write-Verbose "[PASS] Created $FullName "
     $successUsers += $FullName + "," +$SAM
	 foreach ($group in $groups) {
		if ( !($group -eq "")) {
			echo "Adding to $group";
			Add-ADGroupMember "$group" $SAM;
		}
	}
        if ( !($User.Manager -eq "")) {
    		$manager = $User.Manager+","+$rootDomain
           Set-ADUser -Identity $SAM -Manager $manager
	}
    }

}
Catch {
    Write-Warning "[ERROR]Can't create user [$($FullName)] : $_"
    $failedUsers += $FullName + "," +$SAM + "," +$_
}
}
if ( !(test-path $LogFolder)) {
    Write-Verbose "Folder [$($LogFolder)] does not exist, creating"
    new-item $LogFolder -type directory -Force
}


Write-verbose "Writing logs"
$failedUsers   |ForEach-Object {"$($b).) $($_)"; $b++} | out-file -FilePath  $LogFolder\FailedUsers.log -Force -Verbose
$successUsers | ForEach-Object {"$($a).) $($_)"; $a++} | out-file -FilePath  $LogFolder\successUsers.log -Force -Verbose

$su=(Get-Content "$LogFolder\successUsers.log").count
$fu=(Get-Content "$LogFolder\FailedUsers.log").count


Write-Host "$fu Users Creation Failed and " -NoNewline -ForegroundColor red
Write-Host "$su Users Successfully Created "  -NoNewline -ForegroundColor green
Write-Host "--> Launching LogsFolder have a Look and review." -ForegroundColor Magenta
Start-Sleep -Seconds 5
Invoke-Item $LogFolder
