function CreateVariableString{
    Param(
        [parameter(mandatory=$true)][string]$key,
        [parameter(mandatory=$true)][hashtable]$value
    )
    
    $CMakeListTxt = ""
    foreach($value_key in $value.Keys){
        $CMakeListTxt += $Key
        $CMakeListTxt += "("
        $CMakeListTxt += $value_key
        foreach($value_value in $value[$value_key]){        
            $CMakeListTxt+= " "
            $CMakeListTxt += $value_value
        }
        $CMakeListTxt += ")"
        $CMakeListTxt += "`n`r"
    }

    return $CMakeListTxt
}
function CreateIncludeString{
    Param(
        [parameter(mandatory=$true)][string]$key,
        [parameter(mandatory=$true)]$value
    )
    $CMakeListTxt = ""
    foreach($value_value in $value){
        $CMakeListTxt += $Key
        $CMakeListTxt += "("
        $CMakeListTxt += $value_value
        $CMakeListTxt += ")"
        $CMakeListTxt += "`n`r"
    }
    return $CMakeListTxt
}
function CreateMacroCallString{
    Param(
        [parameter(mandatory=$true)][string]$key,
        [parameter(mandatory=$true)]$value
    )

    $CMakeListTxt = ""
    foreach($value_value in $value){
        $CMakeListTxt += $value
        $CMakeListTxt += "`n`r"
    }
    return $CMakeListTxt
}

function CreateCMakeListText{
    Param(
        [parameter(mandatory=$true)][string]$RootPath,
        [parameter(mandatory=$true)][string]$ProjectName,
        [parameter(mandatory=$true)][string]$BuildType,
        [parameter(mandatory=$true)]$IncludeDirectories,
        [parameter(mandatory=$true)]$SourceDirectories,
        [parameter(mandatory=$true)]$ExtensionDirectories,
        [parameter(mandatory=$true)]$LibraryDirectries,
        [parameter(mandatory=$true)]$WorkSpacePath,
        [parameter(mandatory=$true)]$Libraries,
        [parameter(mandatory=$true)]$SourceRootPath,
        [parameter(mandatory=$true)]$SubDirectoryPaths
    )
    $CMakeConfigPath = $RootPath + "Make/cmake/CreateCMakeListConfig.json"
    $CMakeConfigText = Get-Content -Path $CMakeConfigPath -Encoding UTF8
    $CMakeConfigTable = $serializer.Deserialize($CMakeConfigText, [System.Collections.Hashtable])
    
    $CMakeConfigTable["set"]["project_name"] = $ProjectName
    $CMakeConfigTable["set"]["project_root_path"] = $SourceRootPath
    $CMakeConfigTable["set"]["subdirectory_paths"] = $SubDirectoryPaths
    $CMakeConfigTable["set"]["cmake_module_path"] = $RootPath + "Make/cmake/module/"
    $CMakeConfigTable["set"]["source_paths"] = $SourceDirectories
    $CMakeConfigTable["set"]["include_paths"] = $IncludeDirectories
    $CMakeConfigTable["set"]["extension_paths"] = $ExtensionDirectories
    $CMakeConfigTable["set"]["library_paths"] = $LibraryDirectries
    $CMakeConfigTable["set"]["build_type"] = $BuildType
    $CMakeConfigTable["set"]["dependency_lib_names"] = $Libraries

    $CMakeListTxt = ""
    foreach($Key in $CMakeConfigTable["@discription_order"])
    {
        $Value = $CMakeConfigTable[$Key]
        if($Key -eq "cmake_minimum_required"){
            $CMakeListTxt += CreateVariableString $Key $Value
        }
        elseif($Key -eq "set"){
            $CMakeListTxt += CreateVariableString $Key $Value
        }
        elseif($Key -eq "include"){
            $CMakeListTxt += CreateIncludeString $Key $Value
        }
        elseif($Key -eq "macro"){
            $CMakeListTxt += CreateMacroCallString $Key $Value
        }
    }
    #CMakeList.txtを出力
    $CMakeListTxtPath = $WorkSpacePath + "/CMakeLists.txt"
    $CMakeListTxt | Out-File $CMakeListTxtPath -Encoding utf8
}
function CreateBuildEnviromentCmake{
    Param(
        [parameter(mandatory=$true)][hashtable]$ProjectConfig,
        [parameter(mandatory=$true)][hashtable]$CommonConfig,
        [parameter(mandatory=$true)][string]$RootPath,
        [parameter(mandatory=$true)][string]$WorkConfigPath
    )
    $BuildConfigText = Get-Content -Path $WorkConfigPath -Encoding UTF8
    $BuildConfigTable = $serializer.Deserialize($BuildConfigText, [System.Collections.Hashtable])

    $ProjectNameTable = $BuildConfigTable["ProjectName"]
    $BuildTypeTable = $BuildConfigTable["BuildType"]
    $WorkSpaceTable = $BuildConfigTable["WorkSpaceDirectory"]
    $IncludeDirectoryTable = $BuildConfigTable["IncludeDirectory"]
    $SourceDirectoryTable = $BuildConfigTable["SourceDirectory"]
    $LibraryDirectoryTable = $BuildConfigTable["LibraryDirectory"]
    $ExtensionDirectoryTable = $BuildConfigTable["ExtensionDirectory"]
    $LibraryTable = $BuildConfigTable["Library"]
    $SourceRootPathTable = $BuildConfigTable["SourceRootPath"]

    foreach($Key in $WorkSpaceTable.Keys)
    {
        $SubDirectoryPaths = @()
        if($Key -eq $ProjectConfig["ProjectName"]){
            foreach($lib_name in $LibraryTable[$Key]){
                $SubDirectoryPaths += $WorkSpaceTable[$Key] + $lib_name
            }
        }
       CreateCMakeListText $RootPath $ProjectNameTable[$Key] $BuildTypeTable[$Key] $IncludeDirectoryTable[$Key] $SourceDirectoryTable[$Key] $ExtensionDirectoryTable[$Key] $LibraryDirectoryTable[$Key] $WorkSpaceTable[$Key] $LibraryTable[$Key] $SourceRootPathTable[$Key] $SubDirectoryPaths
    }
    
    $CMakeBatchPath = $RootPath + "/Make/cmake/CMakeBuild.bat"
    $ProjectWorkSpace = $WorkSpaceTable[$ProjectConfig["ProjectName"]]
    Copy-Item $CMakeBatchPath $ProjectWorkSpace
    
    Set-Location -Path $ProjectWorkSpace
    cmd.exe /c ".\CMakeBuild.bat"
}