
#$Global:TA=@()


#Enhancement Verify Object creation in original build
#Enhancement ignore default values




function convert-ObjectToCode () {
	param(
		[Parameter(mandatory = $true)] $Object,
		[Parameter(mandatory = $true)] [string]$VarName,
		[bool]$recursion
	)

	if ($($object.GetType().ToString()) -eq "System.RuntimeType" -and $($object.FullName)) {
		$codeString = "`$$($VarName)= New-Object $($object.fullname) `n"
		# write-host "$VarName ::::::::::::: $($object.fullname) "
	}
	else {
		$codeString = "`$$($VarName)= New-Object $($object.gettype().FullName) `n"
	}


	foreach ($prop in (Get-ObjectProperties $Object)) {
		if ((($object. "$($prop.name)".GetType()).IsPrimitive) -or ($object. "$($prop.name)".GetType().Name) -eq "string") {

			switch ($object. "$($prop.name)".GetType().Name) {
				double {
					if ($($object. "$($prop.name)".ToString()) -eq "∞") {
						$codeString += "`$$($VarName).$($prop.name)= [double]::PositiveInfinity `n"

					}
					elseif ($($object. "$($prop.name)".ToString()) -eq "NaN") {
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
					Write-Host ":::: `$$($VarName).$($prop.name)= $($object."$($prop.name)") `n $($object."$($prop.name)".gettype().name)"
				}

			}
		}
		elseif ($recursion -and $($prop.Name) -notmatch "parent") {
			$codeString += convert-ObjectToCode -Object $object. "$($prop.name)" -VarName "$($VarName)_$($prop.name)" -recursion $recursion
			#Write-Host "$($VarName)_$($prop.name) $($object."$($prop.name)".gettype().name)"  

		}

	}

	return $codeString
}

function Get-ObjectProperties () {
	param(
		[Parameter(mandatory = $true)] [object]$Object
	)

	return $object | Get-Member | Where-Object { $_.MemberType -eq "Property" -and $_.definition -match "set;}" -and $object. "$($_.name)" -ne $null }
}




function Test-ObjectDebugger () {
	param(
		[Parameter(mandatory = $true)] $Object,
		[Parameter(mandatory = $true)] [string]$VarName,
		[switch]$recursion
	)
	$codestr = convert-ObjectToCode -Object $Object -VarName "$VarName" -recursion $recursion
	$errorfound = $true
	$unresolvedErrors = @()
	while ($errorfound)
	{
		$codeStr_Error = $null
		$errorfound = $false
		try { Invoke-Expression $codestr -ErrorVariable "codeStr_Error" }
		catch { $errorfound = $true }
		$CurrentError = $codeStr_Error[0]
		Add-Member -InputObject $CurrentError -MemberType NoteProperty -Name "ConstructorName" -Value "$(($CurrentError.message -split "type ")[1].TrimEnd('.'))"
		Add-Member -InputObject $CurrentError -MemberType NoteProperty -Name "LineNumber" -Value ($CurrentError.ErrorRecord.ScriptStackTrace.Split("`n")[0] -split "line ")[1]
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


	$UniqueCodeErrors = $codeStr_Errors.message | sort | Get-Unique
	$constructorErrors = $codeStr_Errors | Where-Object { $_.message -match "A constructor was not found" }
	$constructorErrors | ForEach-Object {
		Add-Member -InputObject $_ -MemberType NoteProperty -Name "ConstructorName" -Value "$(($_.message -split "type ")[1].TrimEnd('.'))"
		Add-Member -InputObject $_ -MemberType NoteProperty -Name "ScriptLine" -Value ($_.ErrorRecord.ScriptStackTrace.Split("`n")[0] -split "line ")[1]
	}

	$UniqueConstructorErrors = ($UniqueCodeErrors -match "A constructor was not found")
	$ConstructorErrorList = @()
	$constructorErrors | ForEach-Object {
		#write-host "$(($_.message -split "type ")[1].TrimEnd('.'))   :::::::::::::: $($_.message)"  
		get-constructors -TypeName "$(($_.message -split "type ")[1].TrimEnd('.'))"
	}


}


function get-constructors () {
	param(
		[Parameter(mandatory = $true)] [string]$TypeName
	)
	Write-Host $TypeName
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



#Test-ObjectDebugger -Object $form -VarName "MYTEST"

#>
#$MyTest.ShowDialog()


#$inputObject
#$objectType = $form.GetType().toString()
#$DString="`$testForm= New-Object $($objectType)"
#Invoke-Expression $DString


