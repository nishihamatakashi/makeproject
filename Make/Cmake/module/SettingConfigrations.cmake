#---------------------------------------------------------------------------------
# @ brief ビルド構成毎の設定
# @ param[in] project_name        : プロジェクト名
# @ param[in] DPENDENCY_LIBS_NAME : 依存しているライブラリ名
# @ param[in] cmake_module_path    : CMakeのモジュールディレクトリ
#---------------------------------------------------------------------------------
macro(setting_configrations project_name cmake_module_path library_paths)
    # Debug,Develop,Releaseをビルド構成に追加
    if(CMAKE_CONFIGURATION_TYPES)
        set(CMAKE_CONFIGURATION_TYPES Debug Develop Release)
    endif()

    # プリプロセッサマクロの定義を記述
    set(COMPILE_DEFINATIONS_COMMON )
    set(COMPILE_DEFINATIONS_DEBUG MODE_DEBUG MODE_TEST_CODE MODE_PROFILE_CODE)
    set(COMPILE_DEFINATIONS_DEVELOP MODE_DEBUG MODE_TEST_CODE MODE_PROFILE_CODE)
    set(COMPILE_DEFINATIONS_RELEASE MODE_RELEASE)

    # コンパイラオプションを記述
    set(COMPILE_OPTIONS_COMMON /fp:fast /Ob1 /Ot /Zi /W4 /WX)
    set(COMPILE_OPTIONS_DEBUG /MTd /Oy- /Od)
    set(COMPILE_OPTIONS_DEVELOP /MT /Oy /O2)
    set(COMPILE_OPTIONS_RELEASE /MT /Oy /O2)

    # ビルド構成毎にプリプロセッサマクロとコンパイラオプションを設定
    foreach(CONFIGRATION_TYPE ${CMAKE_CONFIGURATION_TYPES})

        # 共通設定で初期化
        set(COMPILE_DEFINATIONS ${COMPILE_DEFINATIONS_COMMON})
        set(COMPILE_OPTIONS ${COMPILE_OPTIONS_COMMON})

        # ビルド構成に応じて追加
        if(${CONFIGRATION_TYPE} MATCHES "Debug")
            list(APPEND COMPILE_DEFINATIONS ${COMPILE_DEFINATIONS_DEBUG})
            list(APPEND COMPILE_OPTIONS ${COMPILE_OPTIONS_DEBUG})
        elseif(${CONFIGRATION_TYPE} MATCHES "Develop")
            list(APPEND COMPILE_DEFINATIONS ${COMPILE_DEFINATIONS_DEVELOP})
            list(APPEND COMPILE_OPTIONS ${COMPILE_OPTIONS_DEVELOP})
        elseif(${CONFIGRATION_TYPE} MATCHES "Release")
            list(APPEND COMPILE_DEFINATIONS ${COMPILE_DEFINATIONS_RELEASE})
            list(APPEND COMPILE_OPTIONS ${COMPILE_OPTIONS_RELEASE})
        endif()

        # プリプロセッサマクロを${project_name}に設定
        target_compile_definitions(${project_name} PUBLIC $<$<CONFIG:${CONFIGRATION_TYPE}>:${COMPILE_DEFINATIONS}>)

        # コンパイルオプションを${project_name}に設定
        target_compile_options(${project_name} PUBLIC $<$<CONFIG:${CONFIGRATION_TYPE}>:${COMPILE_OPTIONS}>)

        #リンク設定
        foreach(library_path ${library_paths})
            string(REPLACE @Configuration ${CONFIGRATION_TYPE} link_name ${library_path})
            target_link_libraries(${project_name} PUBLIC $<$<CONFIG:${CONFIGRATION_TYPE}>:${link_name}>)
        endforeach()
    endforeach(CONFIGRATION_TYPE)
endmacro()