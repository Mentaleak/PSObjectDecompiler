
#$Global:TA=@()


#Enhancement Verify Object creation in original build
#Enhancement ignore default values
#Fix read GET properties containing objects and traverse those objects




function convert-ObjectToCode () {
	param(
		[Parameter(mandatory = $true)] $Object,
		[Parameter(mandatory = $true)] [string]$VarName,
		[bool]$recursion,
		[bool]$ignoreDefault
	)

	if ($($object.GetType().ToString()) -eq "System.RuntimeType" -and $($object.FullName)) {
		$codeString = "`$$($VarName)= New-Object $($object.fullname) `n"
		# write-host "$VarName ::::::::::::: $($object.fullname) "
		$constructorName = "$($object.fullname)"
	}
	else {
		$codeString = "`$$($VarName)= New-Object $($object.gettype().FullName) `n"
		$constructorName = "$($object.gettype().FullName)"
	}

	if ($ignoreDefault) {
		#write-host $codeString
		$tempcode = $codeString
		try { Invoke-Expression $codeString }
		catch { $codeString = "<# Constructor_Issue `n"
			$codeString += $tempcode
			$constructordata += (get-constructors $constructorName)
			$codeString += ($constructordata | Format-Table -AutoSize | Out-String)
			$codeString += ($Object | Format-List | Out-String)
			$codeString += "`n #> `n"
			#The lines below needs work!!!!!
			$originobject = $VarName.Split("_")
			$originobjName = "`$form"
			for ($i = 1; $i -lt $originobject.count; $i++)
			{
				$originobjName += ".$($originobject[$i])"
			}
			$codeString += "`$$($VarName)=$($originobjName) `n"
		}
		$tempobj = (Get-Variable -Name "$($VarName)").value
	}
	$objprops = (Get-ObjectProperties $Object)
	foreach ($prop in $objprops) {
		Write-Host "$($prop.name)"
		#write-host ":: $ignoreDefault -and $($tempobj."$($prop.name)") -ne $($object."$($prop.name)")"
		if (($ignoreDefault -and $tempobj."$($prop.name)" -ne $object."$($prop.name)") -or (!($ignoreDefault))) {
			if ((($object."$($prop.name)".GetType()).IsPrimitive) -or ($object."$($prop.name)".GetType().Name) -eq "string") {

				switch ($object."$($prop.name)".GetType().Name) {
					double {
						if ($($object."$($prop.name)".ToString()) -eq "∞") {
							$codeString += "`$$($VarName).$($prop.name)= [double]::PositiveInfinity `n"

						}
						elseif ($($object."$($prop.name)".ToString()) -eq "NaN") {
							$codeString += "`$$($VarName).$($prop.name)= [Double]::NAN `n"

						}
						else {
							$codeString += "`$$($VarName).$($prop.name)= $($object."$($prop.name)") `n"
						}
					}
					{ ($_ -match "int" -or $_ -match "single") } {
						$codeString += "`$$($VarName).$($prop.name)= $($object."$($prop.name)") `n"
					}
					{ ($_ -match "bool") } {
						$codeString += "`$$($VarName).$($prop.name)= `$$($object."$($prop.name)") `n"
					}
					String {
						$codeString += "`$$($VarName).$($prop.name)= `"$($object."$($prop.name)")`" `n"
					}
					byte {
						$codeString += "`$$($VarName).$($prop.name)= $($object."$($prop.name)") `n"
					}
					default {
						$codeString += "`$$($VarName).$($prop.name)= $($object."$($prop.name)") `n"
						Write-Host "::::HANDLE ME:::::: `$$($VarName).$($prop.name)= $($object."$($prop.name)") `n $($object."$($prop.name)".gettype().name)"
					}

				}
			}
			elseif ($recursion -and $($prop.Name) -notmatch "parent" -and $($prop.Name) -notmatch "tag") {
				$codeString += convert-ObjectToCode -Object $object."$($prop.name)" -VarName "$($VarName)_$($prop.name)" -recursion $recursion -ignoreDefault $ignoredefault
				#Write-Host "$($VarName)_$($prop.name) $($object."$($prop.name)".gettype().name)"  

			}
		}
	}

	return $codeString
}

function Get-ObjectProperties () {
	param(
		[Parameter(mandatory = $true)] [object]$Object
	)

	return $object | Get-Member | Where-Object { $_.MemberType -eq "Property" -and $_.definition -match "set;}" -and $object."$($_.name)" -ne $null }
}




function Test-ObjectDebugger () {
	param(
		[Parameter(mandatory = $true)] $Object,
		[Parameter(mandatory = $true)] [string]$VarName,
		[switch]$recursion,
		[switch]$ignoredefault
	)
	Write-Host ("This WILL SCREAM")
	$codestr = convert-ObjectToCode -Object $Object -VarName "$VarName" -recursion $recursion -ignoreDefault $ignoredefault
	$unresolvedErrors = @()
	Invoke-Expression $codestr -ErrorVariable "codeStr_Errors"



	<#while ($errorfound)
	{
		$codeStr_Error = $null
		$errorfound = $false
		try { Invoke-Expression $codestr -ErrorVariable "codeStr_Error" }
		catch { if( $codeStr_Error[0].Exception.message -match "A constructor was not found"){$constructorError = $true };$errorfound = $true}
        if($constructorError){
            $codeStr_Error[0]
		    $CurrentError = $codeStr_Error[0]

		    Add-Member -InputObject $CurrentError -MemberType NoteProperty -Name "ConstructorName" -Value "$(($CurrentError.exception.message -split "type ")[1].TrimEnd('.'))"
		    Add-Member -InputObject $CurrentError -MemberType NoteProperty -Name "LineNumber" -Value ($CurrentError.exception.ErrorRecord.ScriptStackTrace.Split("`n")[0] -split "line ")[1]
		    Add-Member -InputObject $CurrentError -MemberType NoteProperty -Name "LineCode" -Value ($codestr.Split("`n")[($CurrentError.ScriptLine - 1)])


		    $constructorOptions = get-constructors -TypeName $($CurrentError.ConstructorName)
		    if ($constructorOptions[0].Name -like "Error_*") {
			    $ChooseConstructor = [System.Windows.MessageBox]::Show("A constructor must be chosen for type: `n `n $($CurrentError.ConstructorName) `n`n Unfortunately one cannot be determined it will have to be manually handled. GOOD LUCK!",'Choose Constructor','ok','ERROR')
			    $unresolvedErrors += $CurrentError
		    } else {
			    $ChooseConstructor = [System.Windows.MessageBox]::Show("A constructor must be chosen for type: `n `n $($CurrentError.ConstructorName)",'Choose Constructor','ok','Information')
			    $ChosenConstructor = $constructorOptions | Out-GridView
		    }
        }
	}
#>

	$UniqueCodeErrors = $codeStr_Errors.message | sort | Get-Unique
	$constructorErrors = $codeStr_Errors | Where-Object { $_.message -match "A constructor was not found" }
	$constructorErrors | ForEach-Object {
		Add-Member -InputObject $_ -MemberType NoteProperty -Name "ConstructorName" -Value "$(($_.message -split "type ")[1].TrimEnd('.'))"
		Add-Member -InputObject $_ -MemberType NoteProperty -Name "ConstructorOptions" -Value (get-constructors "$(($_.message -split "type ")[1].TrimEnd('.'))")
		Add-Member -InputObject $_ -MemberType NoteProperty -Name "LineNumber" -Value ($_.ErrorRecord.ScriptStackTrace.Split("`n")[0] -split "line ")[1]
		Add-Member -InputObject $_ -MemberType NoteProperty -Name "LineCode" -Value ($codestr.Split("`n")[($_.ScriptLine - 1)])
	}

	$UniqueConstructorErrors = ($UniqueCodeErrors -match "A constructor was not found")


	$ObjectData = [pscustomobject]@{
		ConstructorErrors = $constructorErrors
		UniqueConstructorErrors = $UniqueConstructorErrors
		codeErrors = $codeStr_Errors
		UniqueCodeErrors = $UniqueCodeErrors
		Code = $codestr
		GeneratedObject = (Get-Variable -Name "$VarName")
	}
	Write-Host ("I AM DONE SCREAMING")
	return $ObjectData

	<######
	$constructorErrors | ForEach-Object {
		#write-host "$(($_.message -split "type ")[1].TrimEnd('.'))   :::::::::::::: $($_.message)"  

		$constructorOptions = get-constructors -TypeName $($_.ConstructorName)
		if ($constructorOptions[0].Name -like "Error_*") {
			$ChooseConstructor = [System.Windows.MessageBox]::Show("A constructor must be chosen for type: `n `n $($_.ConstructorName) `n`n Unfortunately one cannot be determined it will have to be manually handled. GOOD LUCK!",'Choose Constructor','ok','ERROR')
			$unresolvedErrors += $CurrentError
		} else {
			$ChooseConstructor = [System.Windows.MessageBox]::Show("A constructor must be chosen for type: `n `n $($_.ConstructorName)",'Choose Constructor','ok','Information')
			$ChosenConstructor = $constructorOptions | Out-GridView
		}
	}

#>
}


function get-constructors () {
	param(
		[Parameter(mandatory = $true)] [string]$TypeName
	)
	#Write-Host $TypeName
	$constructorsData = @()
	$constructors = ([type]"$($TypeName)").DeclaredConstructors | Where-Object { $_.CustomAttributes.attributetype.Name -ne "ObsoleteAttribute" }

	if ($constructors) {
		$constructors | ForEach-Object {
			$constructor = [pscustomobject]@{
				Name = "$($TypeName)_Ctor_$($_.MetadataToken)"
				parameters = ($_.GetParameters() | Select-Object Name).Name -join ", "
				parameterData = ($_.GetParameters())
			}
			$constructorsData += $constructor
		}
	}
	else {
		$constructor = [pscustomobject]@{
			Name = "Error_$($TypeName)"
			parameters = $null
			parameterData = $null
		}
		$constructorsData += $constructor
	}
	return $constructorsData
}



$TestData = Test-ObjectDebugger -Object $form -VarName "MYTEST" -recursion -ignoreDefault
$MountainViewData = Test-ObjectDebugger -Object $Form.FindName("MountainView") -VarName "TMountainView" -recursion -ignoreDefault
$RiverViewData = Test-ObjectDebugger -Object $Form.FindName("RiverView") -VarName "TRiverView" -recursion -ignoreDefault
$sandViewData = Test-ObjectDebugger -Object $Form.FindName("sandView") -VarName "TsandView" -recursion -ignoreDefault
$AboutViewData = Test-ObjectDebugger -Object $Form.FindName("AboutView") -VarName "TAboutView" -recursion -ignoreDefault
$HamburgerMenuControlData = Test-ObjectDebugger -Object $Form.FindName("HamburgerMenuControl") -VarName "THamburgerMenuControl" -recursion -ignoreDefault
#$TestData2 = Test-ObjectDebugger -Object $Form.RightWindowCommands.LightTemplate.Resources.BaseUri -VarName "ttttt" -recursion -ignoreDefault
#>
#$MyTest.ShowDialog()


#$inputObject
#$objectType = $form.GetType().toString()
#$DString="`$testForm= New-Object $($objectType)"
#Invoke-Expression $DString


