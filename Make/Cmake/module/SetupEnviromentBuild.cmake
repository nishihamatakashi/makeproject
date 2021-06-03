#---------------------------------------------------------------------------------
# @ brief セットアップ処理
# @ param[in] project_name        : プロジェクト名
# @ param[in] project_root_path    : プロジェクトのrootディレクトリ 
# @ param[in] source_paths          : プロジェクトのソースディレクトリ
# @ param[in] include_paths         : プロジェクトのインクルードディレクトリ
# @ param[in] extension_paths       : 上記以外のディレクトリ
# @ param[in] dependency_lib_names : 依存しているライブラリ名
# @ param[in] build_type          : ビルド種別(execute.exe,static:.lib,shared:.dll)
# @ param[in] cmake_module_path    : CMakeのモジュールディレクトリ
#---------------------------------------------------------------------------------
macro(setup_build_enviroment)
    # コンパイル対象のソース
    set(compile_target_sources "")

    #source_pathsから.h,.cppファイルを収集し,compile_target_sourcesに追加
    foreach(src_path ${source_paths})
        if(src_path)
            file(GLOB_RECURSE source_codes ${src_path}/*.cpp ${src_path}/*.h)
            LIST(APPEND compile_target_sources ${source_codes} )
        endif()
    endforeach()
    
    #project作成
    project(${project_name})

    #インクルードディレクトリの設定
    include_directories(${include_paths})

    #依存しているライブラリがある場合はサブディレクトリ追加を行う
    foreach(subdirectory ${subdirectory_paths}) 
        add_subdirectory(${subdirectory} ${subdirectory})
    endforeach()

    #ソースをすべてプロジェクトに登録
    if(${build_type} STREQUAL "execute")
        add_executable(${project_name} ${compile_target_sources})
    elseif(${build_type} STREQUAL "static")
        add_library(${project_name} STATIC ${compile_target_sources})
    elseif(${build_type} STREQUAL "shared")
        add_library(${project_name} SHARED ${compile_target_sources})
    endif()

    include(${cmake_module_path}/CreateSourceGroup.cmake)

    # ソースのフィルタ分けを行う
    if(source_paths)
        foreach(src_path ${source_paths})
            create_source_group(${src_path} ${project_root_path}/_build)
        endforeach()
    endif()
    if(extension_paths)
        foreach(ext_path ${extension_paths})
            create_source_group(${ext_path} ${project_root_path})
        endforeach()
    endif()
    
    #ビルドの依存関係を記述
    foreach(lib_name ${dependency_lib_names})
        add_dependencies(${project_name} ${lib_name})
    endforeach()

    include(${cmake_module_path}/SettingConfigrations.cmake)

    #ビルド構成毎の設定
    setting_configrations(${project_name} ${cmake_module_path} ${library_paths})
endmacro()