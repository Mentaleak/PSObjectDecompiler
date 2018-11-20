


function convert-ObjectToCode () {
	param(
		[Parameter(mandatory = $true)] $Object,
		[string]$VarName,
		[switch]$recursion
	)

	$codeString = "`$$($VarName)= New-Object $($object.GetType().toString()) `n"
	foreach ($prop in (Get-ObjectProperties $Object)) {
		if ((($object. "$($prop.name)".GetType()).IsPrimitive)) {
			switch ($object. "$($prop.name)".GetType().Name) {
				{ ($_ -eq "double") -or ($_ -match "int") } {
					$codeString += "`$$($VarName).$($prop.name)= $($object."$($prop.name)") `n"
				}
				{ ($_ -match "bool") } {
					$codeString += "`$$($VarName).$($prop.name)= `$$($object."$($prop.name)") `n"
				}
				String {
					$codeString += "`$$($VarName).$($prop.name)= `"$($object."$($prop.name)")`" `n"
				}
				default {
					$codeString += "`$$($VarName).$($prop.name)= $($object."$($prop.name)") `n"
					Write-Host "$($prop.name) $($object."$($prop.name)".gettype().name)"
				}

			}
		}
		elseif ($recursion) {
			Write-Host "$($prop.name) $($object."$($prop.name)".gettype().name)"
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



$codestr = convert-ObjectToCode -Object $form -VarName "MYTEST" -recursion
#Invoke-Expression $codestr
#$MyTest.ShowDialog()


#$inputObject
#$objectType = $form.GetType().toString()
#$DString="`$testForm= New-Object $($objectType)"
#Invoke-Expression $DString
