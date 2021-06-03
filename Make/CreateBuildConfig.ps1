#/* --------------------------------------------------
#* @brief Make情報のハッシュテーブル
#* ProjectNameTable         :プロジェクト毎のプロジェクト名
#* BuildTypeTable           :プロジェクト毎のビルド種別
#* LibraryTable             :プロジェクト毎の内部依存ライブラリ情報
#* ThirdPartyTable          :プロジェクト毎の外部依存ライブラリ情報
#* IncludeDirectoryTable    :プロジェクト毎のincludeディレクトリ情報
#* SourceDirectory          :プロジェクト毎のコンパイル対象のディレクトリ情報
#* LibraryDirectoryTable    :プロジェクト毎の依存ライブラリディレクトリ情報
#* ExtensionDirectoryTable  :プロジェクト毎の拡張ディレクトリ情報
#* WorkSpaceDirectoryTable  :プロジェクト毎の作業ディレクトリ情報
#* SourceRootPathTable      :プロジェクト毎のソースのルートパス情報
#*/ --------------------------------------------------
$ProjectNameTable = @{}
$BuildTypeTable = @{}
$LibraryTable = @{}
$ThirdPartyTable = @{}
$IncludeDirectoryTable = @{}
$SourceDirectoryTable = @{}
$LibraryDirectoryTable = @{}
$ExtensionDirectoryTable = @{}
$WorkSpaceDirectoryTable = @{}
$SourceRootPathTable = @{}

#/* --------------------------------------------------
#* @brief 依存情報を収集する
#* @param[in] ProjectName       :対象のプロジェクト名
#* @param[in] LibraryNames      :依存している内製ライブラリ配列
#* @param[in] ThirdPartyNames   :依存している外製ライブラリ配列
#* @param[in] RootPath          :ライブラリのルートパス
#*/ --------------------------------------------------
function CorrectDpendName{
    Param(
        [parameter(mandatory=$true)][string]$ProjectName,
        [parameter(mandatory=$true)]$LibraryNames,
        [parameter(mandatory=$true)]$ThirdPartyNames,
        [parameter(mandatory=$true)][string]$RootPath
    )

    # $LibraryTableのkeyに$ProjectNameが無ければ追加
    if(-not($LibraryTable.ContainsKey($ProjectName)))
    {
        $LibraryTable.add($ProjectName,$LibraryNames);
    }

    # $ThirdPartyTableのkeyに$ProjectNameが無ければ追加
    if(-not($ThirdPartyTable.ContainsKey($ProjectName)))
    {
        $ThirdPartyTable.add($ProjectName,$ThirdPartyNames);
    }

    # 依存している内製ライブラリのConfig情報を取得
    # 次の依存先のライブラリを再帰で収集する
    foreach($Library in $LibraryNames)
    {
        $LibraryConfigPath = $RootPath + "Make/Configuration/Library/" + $Library + ".json"
        $LibraryConfig = Get-Content -Path $LibraryConfigPath| ConvertFrom-Json
        CorrectDpendName $Library $LibraryConfig.DependLibrary $LibraryConfig.DependThirdParty $RootPath
    }
}

#/* --------------------------------------------------
#* @brief 同じ名前が入ってないものを挿入する
#* @param[in]dstNames:挿入先の名前配列
#* @param[in]srcNames:挿入元の名前配列
#*/ --------------------------------------------------
function InsertDiffName
{
    Param(
        [parameter(mandatory=$true)]$dstNames,
        [parameter(mandatory=$true)]$srcNames
    )
    foreach ( $srcName in $srcNames )
    {
        $isSameName = 0
        foreach($dstName in $dstNames)
        {
            if($srcName -eq $dstName)
            {
                $isSameName = 1
                break
            }
        }
        if(-not($isSameName))
        {
            $dstNames += $srcName
        }
    }
    return $dstNames
}

#/* --------------------------------------------------
#* @brief 収集した内部ライブラリの依存情報を整理する
#* @param[in] ProjectName:整理対象のプロジェクト名
#* @detail 具体的には依存しているライブラリについて
#          さらに依存しているライブラリもkey毎に記述していく
#*/ --------------------------------------------------
function RefactorDependName{
    Param(
        [parameter(mandatory=$true)]$ProjectName
    )
    #依存している内部ライブラリ名、外部ライブラリ名を取得
    $DependLibraryNames = $LibraryTable[$ProjectName]
    $DependThirdPartyNames = $ThirdPartyTable[$ProjectName]

    #library,thirdpartyをkeyとするハッシュテーブルを作成
    $DependTable = @{
        "library" = ""
        "thirdparty" = ""
    }
    
    #ハッシュテーブル内に名前が重複しないように挿入していく
    foreach ( $DependLibraryName in $DependLibraryNames ){
        $table = RefactorDependName $DependLibraryName
        $LibraryTable[$ProjectName] = InsertDiffName $DependLibraryNames $table["library"]
        $ThirdPartyTable[$ProjectName] = InsertDiffName  $DependThirdPartyNames $table["thirdParty"]
    }

    #自身が持つライブラリ情報を挿入
    $DependTable["library"] = $LibraryTable[$ProjectName]
    $DependTable["thirdparty"] = $ThirdPartyTable[$ProjectName]

    return $DependTable
}

function ReplaceConfiguration{
    Param(
        [parameter(mandatory=$true)][hashtable]$TypeConfig,
        [parameter(mandatory=$true)]$ReplaceTypeConfig,
        [parameter(mandatory=$true)][string]$SrcPath
    )
    
    foreach($value in $ReplaceTypeConfig){
        $SrcPath.Replace($value,$TypeConfig[$value]);
    }
    return $SrcPath
}

#/* --------------------------------------------------
#* @brief LibraryTableをもとに各種ディレクトリ情報を収集する
#* @param[in] ProjectName       :ビルド対象のプロジェクト名
#* @param[in] RootPath          :ライブラリのルートパス
#* @param[in] WorkSpaceRootPath :作業ディレクトリのルートパス
#*/ --------------------------------------------------
function CorrectDirectory{
    Param(
        [parameter(mandatory=$true)][hashtable]$TypeConfig,
        [parameter(mandatory=$true)]$ReplaceTypeConfig,
        [parameter(mandatory=$true)][string]$ProjectName,
        [parameter(mandatory=$true)][string]$ProjectDir,
        [parameter(mandatory=$true)][string]$RootPath,
        [parameter(mandatory=$true)][string]$WorkSpaceRootPath
    )
    
    # 依存している内部ライブラリ毎に、各種ディレクトリ情報を収集する
    # include,source,library
    foreach($Key in $LibraryTable.Keys){
        #依存している内部ライブラリを取得
        $DependLibraryNames = $LibraryTable[$Key]

        #各種ディレクトリ情報に対して各種key情報挿入
        $IncludeDirectoryTable.add($Key,"")
        $SourceDirectoryTable.add($Key,"")
        $LibraryDirectoryTable.add($key,"")

        # value値の一時保存変数
        $inc_array = @()
        $src_array = @()
        $lib_array = @()

        #依存している内部ライブラリ全てにおいて、各種ディレクトリ情報を一時保存変数に挿入
        foreach($DependLibraryName in $DependLibraryNames){
            #各種ライブラリのビルド情報を取得
            $LibraryConfigPath = $RootPath + "Make/Configuration/Library/" + $DependLibraryName + ".json"
            $LibraryConfig = Get-Content -Path $LibraryConfigPath| ConvertFrom-Json

            #includeディレクトリ情報を挿入
            foreach($inc in $LibraryConfig.IncludeDirectory)
            {
                $Path = $RootPath + "Library/" + $DependLibraryName + "/" + $inc
                foreach($value in $ReplaceTypeConfig){
                    if($Path.Contains($value)){
                        $Path = $Path.Replace($value,$TypeConfig[$value]);
                    }
                }
                $inc_array += $Path
            }

            #sourceディレクトリ情報を挿入
            foreach($src in $LibraryConfig.SourceDirectory)
            {
                $Path = $RootPath + "Library/" + $DependLibraryName + "/" + $src
                foreach($value in $ReplaceTypeConfig){
                    if($Path.Contains($value)){
                        $Path = $Path.Replace($value,$TypeConfig[$value]);
                    }
                } 
                $src_array += $Path      
            }

            #libraryディレクトリ情報を挿入
            $lib_array += $WorkSpaceRootPath + $DependLibraryName + "/@Configuration/" + $DependLibraryName + ".lib"
        }

        #テーブルに挿入
        $IncludeDirectoryTable[$Key] = $inc_array
        $SourceDirectoryTable[$Key] = $src_array
        $LibraryDirectoryTable[$key] = $lib_array
    }

    # 依存している外部ライブラリ毎に、各種ディレクトリ情報を収集する
    # include,source,library
    foreach($Key in $ThirdPartyTable.Keys){
        #依存している外部ライブラリを取得
        $ThirdPartyNames = $ThirdPartyTable[$Key]

        #一時保存変数を既存テーブルのvalue値で初期化
        $inc_array = $IncludeDirectoryTable[$Key]
        $lib_array =  $LibraryDirectoryTable[$key]

        #依存している外部ライブラリ全てにおいて、各種ディレクトリ情報を一時保存変数に挿入
        foreach($ThirdPartyName in $ThirdPartyNames){
            #外部ライブラリのビルド情報を取得
            $ThirdPartyConfigPath = $RootPath + "Make/Configuration/ThirdParty/" + $ThirdPartyName + ".json"
            $ThirdPartyConfig = Get-Content -Path $ThirdPartyConfigPath| ConvertFrom-Json

            #includeディレクトリ情報を挿入
            foreach($inc in $ThirdPartyConfig.IncludeDirectory)
            {
                $Path = $RootPath + "ThirdParty/" + $ThirdPartyName + "/" + $inc
                foreach($value in $ReplaceTypeConfig){
                    if($Path.Contains($value)){
                        $Path = $Path.Replace($value,$TypeConfig[$value]);
                    }
                }
                $inc_array += $Path
            }

            #libraryディレクトリ情報を挿入
            foreach($lib in $ThirdPartyConfig.LibraryDirectory)
            {
                $Path = $RootPath + "ThirdParty/" + $ThirdPartyName + "/" + $lib
                foreach($value in $ReplaceTypeConfig){
                    if($Path.Contains($value)){
                        $Path = $Path.Replace($value,$TypeConfig[$value]);
                    }
                }
                $lib_list = Get-ChildItem $Path
                foreach($lib in $lib_list){
                    if($lib.Name.Contains(".lib"))
                    {
                        $lib_array += $Path + "/" + $lib.Name
                    }
                }
            }

        }

        #テーブルに挿入
        $IncludeDirectoryTable[$Key] = $inc_array
        $LibraryDirectoryTable[$Key] = $lib_array
    }

    #各プロジェクト毎において自身が持つディレクトリ情報を収集する
    foreach($Key in $LibraryTable.Keys){

        $ProjectNameTable.add($key,"")
        $BuildTypeTable.add($key,"")
        $ExtensionDirectoryTable.add($key,"")
        $SourceRootPathTable.add($key,"")
        #一時保存変数を既存テーブルのvalue値で初期化
        $ConfigProjectName = ""
        $BuildType = ""
        $inc_array = $IncludeDirectoryTable[$Key]
        $src_array = $SourceDirectoryTable[$Key]
        $ext_array = @()
        

        #ビルド情報があるjsonファイルパスを設定
        $LibraryConfigPath = $RootPath + "Make/Configuration/Library/" + $Key + ".json"
        $ProjectRootPath = $RootPath + "Library/" + $Key + "/"

        #ライブラリじゃない(exeデータ)プロジェクトはビルド情報のパスが違うので変更
        if($Key -eq $ProjectName)
        {
            $LibraryConfigPath = $ProjectDir + "/Configuration.json"
            $ProjectRootPath = $ProjectDir
        }

        #ビルド情報を取得
        $LibraryConfig = Get-Content -Path $LibraryConfigPath| ConvertFrom-Json

        #includeディレクトリ情報を挿入
        foreach($inc in $LibraryConfig.IncludeDirectory)
        {
            $Path = $ProjectRootPath + $inc
            foreach($value in $ReplaceTypeConfig){
                if($Path.Contains($value)){
                    $Path = $Path.Replace($value,$TypeConfig[$value]);
                }
            }
            $inc_array += $Path
        }

        #sourceディレクトリ情報を挿入
        foreach($src in $LibraryConfig.SourceDirectory)
        {
            $Path = $ProjectRootPath + $src
            foreach($value in $ReplaceTypeConfig){
                if($Path.Contains($value)){
                    $Path = $Path.Replace($value,$TypeConfig[$value]);
                }
            }
            $src_array += $Path
        }
        #extensionディレクトリ情報を挿入
        foreach($ext in $LibraryConfig.ExtensionDirectory)
        {
            $Path = $ProjectRootPath + $ext
            foreach($value in $ReplaceTypeConfig){
                if($Path.Contains($value)){
                    $Path = $Path.Replace($value,$TypeConfig[$value]);
                }
            }
            $ext_array += $Path
        }
        
        $ConfigProjectName = $LibraryConfig.ProjectName
        $BuildType = $LibraryConfig.BuildType
    
        #テーブルに挿入
        $IncludeDirectoryTable[$Key] = $inc_array
        $SourceDirectoryTable[$Key] = $src_array
        $ExtensionDirectoryTable[$Key] = $ext_array
        $ProjectNameTable[$Key] = $ConfigProjectName
        $BuildTypeTable[$Key] = $BuildType
        $SourceRootPathTable[$Key] = $ProjectRootPath
    }
}

function RefactorDirectory{
    Param(
        [parameter(mandatory=$true)]$Config
    )

}

#/* --------------------------------------------------
#* @brief 作業ディレクトリを作成する
#* @param[in] ProjectName   :ビルド対象のプロジェクト名
#* @param[in] $RootWorkPath :作業ディレクトリのルートパス
#*/ --------------------------------------------------
function CreateWorkSpace{
    Param(
        [parameter(mandatory=$true)]$ProjectName,
        [parameter(mandatory=$true)]$RootWorkPath
    )
    #ワークディレクトリがある場合削除して再作成
    if((Test-Path $RootWorkPath))
    {
        Remove-Item $RootWorkPath -Force -Recurse
    }
    mkdir $RootWorkPath

    #テーブルにパスを挿入しておく
    $WorkSpaceDirectoryTable.add($ProjectName, $RootWorkPath)

    # 依存しているライブラリのworkspaceもRootWorkPath以下に作成する
    $DependLibraryNames = $LibraryTable[$ProjectName]
    foreach($DependLibraryName in $DependLibraryNames)
    {
        $LibraryWorkPath = $RootWorkPath + $DependLibraryName
        mkdir $LibraryWorkPath

        #テーブルにパス挿入しておく
        $WorkSpaceDirectoryTable.add($DependLibraryName, $LibraryWorkPath)
    }
}

#/* --------------------------------------------------
#* @brief ビルド情報を生成する
#* @param[in] Config           :対象のビルド情報
#* @param[in] RootPath         :ライブラリのルートパス
#* @param[in] ProjectPath      :ビルド対象のルートパス
#* @param[in] WorkPath         :作業ディレクトリのパス
#* @param[in] WorkConfigPath   :ビルド情報の出力パス
#*
#* @detail 最終的には、下記情報を作業ディレクトリ下に$WorkConfigPath(jsonファイル)として出力する
#* LibraryTable             :プロジェクト毎の内部依存ライブラリ情報
#* ThirdPartyTable          :プロジェクト毎の外部依存ライブラリ情報
#* IncludeDirectoryTable    :プロジェクト毎のincludeディレクトリ情報
#* SourceDirectory          :プロジェクト毎のコンパイル対象のディレクトリ情報
#* LibraryDirectoryTable    :プロジェクト毎の依存ライブラリディレクトリ情報
#* WorkSpaceDirectoryTable  :プロジェクト毎の作業ディレクトリ情報
#*
#*/ --------------------------------------------------
function CreateBuildConfig{
    Param(
        [parameter(mandatory=$true)][hashtable]$ProjectConfig,
        [parameter(mandatory=$true)][hashtable]$CommonConfig,
        [parameter(mandatory=$true)][string]$RootPath,
        [parameter(mandatory=$true)][string]$ProjectPath,
        [parameter(mandatory=$true)][string]$WorkPath,
        [parameter(mandatory=$true)][string]$WorkConfigPath
    )

    #依存しているライブラリを収集する
    CorrectDpendName $ProjectConfig["ProjectName"] $ProjectConfig["DependLibrary"] $ProjectConfig["DependThirdParty"] $RootPath
    RefactorDependName $ProjectConfig["ProjectName"]

    #各プロジェクトのinclude,source,libディレクトリを収集
    CorrectDirectory $ProjectConfig["TypeConfig"] $CommonConfig["ReplaceTypeConfig"] $ProjectConfig["ProjectName"] $ProjectPath $RootPath $WorkPath

    #ワークスペースパスを設定し、作成
    CreateWorkSpace $ProjectConfig["ProjectName"] $WorkPath

    #ビルド情報をハッシュテーブルにしてまとめる
    $BuildConfig = @{
    }
    $BuildConfig.add("ProjectName",$ProjectNameTable)
    $BuildConfig.add("BuildType",$BuildTypeTable)
    $BuildConfig.add("Library",$LibraryTable)
    $BuildConfig.add("Thirdparty",$ThirdPartyTable)
    $BuildConfig.add("IncludeDirectory",$IncludeDirectoryTable)
    $BuildConfig.add("SourceDirectory",$SourceDirectoryTable)
    $BuildConfig.add("LibraryDirectory",$LibraryDirectoryTable)
    $BuildConfig.add("ExtensionDirectory",$ExtensionDirectoryTable)
    $BuildConfig.add("WorkSpaceDirectory",$WorkSpaceDirectoryTable)
    $BuildConfig.add("SourceRootPath",$SourceRootPathTable)
    #ビルド情報を$WorkConfigPath(jsonファイル)として出力
    $BuildConfig | ConvertTo-Json | Out-File $WorkConfigPath
}