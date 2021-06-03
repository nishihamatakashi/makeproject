Param(
    [parameter(mandatory=$true)][string]$RootPath,
    [parameter(mandatory=$true)][string]$ProjectPath,
    [parameter(mandatory=$true)][string]$ConfigPath
)
Add-Type -AssemblyName System.Web.Extensions
$serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer

function CreateBuildEnviroment
{
    Param(
        [parameter(mandatory=$true)][string]$RootPath,
        [parameter(mandatory=$true)][string]$ProjectPath,
        [parameter(mandatory=$true)][string]$ConfigPath
    )
    Write-Host $RootPath
    $RootPath = $RootPath.Replace("\","/")
    $ProjectPath = $ProjectPath.Replace("\","/")
    $ConfigPath = $ConfigPath.Replace("\","/")
    #RootPathへ移動
    Set-Location -Path $RootPath
    
    #$ConfigPath(Jsonファイル)をHashTableにパース
    $ProjectConfigTxt = Get-Content -Path $ConfigPath -Encoding UTF8
    $ProjectConfig = $serializer.Deserialize($ProjectConfigTxt, [System.Collections.Hashtable])

    #Common.jsonをHashTableにパース
    $CommonConfigPath = $RootPath + "Make/Configuration/Common/Common.json"
    $CommonConfigTxt = Get-Content -Path $CommonConfigPath -Encoding UTF8
    $CommonConfig = $serializer.Deserialize($CommonConfigTxt, [System.Collections.Hashtable])

    #WorkSpaceパスを設定
    $WorkPath = $RootPath + $ProjectConfig["WorkSpacePath"] + "/"
    $WorkConfigPath = $WorkPath + "BuildConfig.json"

    #基本ビルド情報を生成
    ."Make/CreateBuildConfig.ps1"
    CreateBuildConfig $ProjectConfig $CommonConfig $RootPath $ProjectPath $WorkPath $WorkConfigPath

    $TypeConfig = $ProjectConfig["TypeConfig"]

    #MakeTypeに合わせてビルド環境を生成する
    if($TypeConfig["@MakeType"] -eq "CMake"){
        ."Make/cmake/CreateBuildEnviromentCmake.ps1"
        CreateBuildEnviromentCmake $ProjectConfig $CommonConfig $RootPath $WorkConfigPath 
    }
}

CreateBuildEnviroment $RootPath $ProjectPath $ConfigPath