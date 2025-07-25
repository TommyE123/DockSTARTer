#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

menu_app_select() {
    local Title="Select Applications"

    local -a AppList AddedApps
    local AppListFile AddedAppsFile

    AppListFile=$(mktemp)
    AddedAppsFile=$(mktemp)
    {
        local -a AllApps
        readarray -t AllApps < <((
            run_script 'app_list_added'
            run_script 'app_list_nondepreciated'
        ) | tr '[:upper:]' '[:lower:]' | sort -u)
        echo "Currently added applications:"
        local LastAppLetter=''
        for APPNAME in "${AllApps[@]-}"; do
            local main_yml
            main_yml="$(run_script 'app_instance_file' "${APPNAME}" ".yml")"
            if [[ -f ${main_yml} ]]; then
                local AppLetter=${APPNAME:0:1}
                AppLetter=${AppLetter^^}
                if [[ -n ${LastAppLetter-} && ${LastAppLetter} != "${AppLetter}" ]]; then
                    printf '%s\n' "" "" "OFF" >> "${AppListFile}"
                fi
                LastAppLetter=${AppLetter}
                local main_yml
                arch_yml="$(run_script 'app_instance_file' "${APPNAME}" ".${ARCH}.yml")"
                if [[ -f ${arch_yml} ]]; then
                    local AppName
                    AppName=$(run_script 'app_nicename_from_template' "${APPNAME}")
                    local AppDescription
                    AppDescription=$(run_script 'app_description_from_template' "${APPNAME}")
                    local AppOnOff
                    if run_script 'app_is_added' "${APPNAME}"; then
                        echo "   ${APPNAME}"
                        AppOnOff="on"
                        printf '%s\n' "${AppName}" >> "${AddedAppsFile}"
                    else
                        AppOnOff="off"
                    fi
                    printf '%s\n' "${AppName}" "${AppDescription}" "${AppOnOff}" >> "${AppListFile}"
                fi
            fi
        done
    } |& dialog_pipe "${DC[TitleSuccess]}${Title}" "Preparing app menu. Please be patient, this can take a while." "${DIALOGTIMEOUT}"

    readarray -t AddedApps < "${AddedAppsFile}"
    readarray -t AppList < "${AppListFile}"
    rm "${AddedAppsFile}" "${AppListFile}" &> /dev/null

    local -i SelectedAppsDialogButtonPressed
    local SelectedApps
    if [[ ${CI-} == true ]]; then
        SelectedAppsDialogButtonPressed=${DIALOG_CANCEL}
    else
        local SelectAppsDialogText="Choose which apps you would like to install:\n Use ${DC["KeyCap"]}[up]${DC[NC]}, ${DC["KeyCap"]}[down]${DC[NC]}, and ${DC["KeyCap"]}[space]${DC[NC]} to select apps, and ${DC["KeyCap"]}[tab]${DC[NC]} to switch to the buttons at the bottom."
        local SelectedAppsDialogParams=(
            --stdout
            --title "${DC["Title"]}${Title}"
        )
        local -i MenuTextLines
        MenuTextLines="$(_dialog_ "${SelectedAppsDialogParams[@]}" --print-text-size "${SelectAppsDialogText}" "$((LINES - DC["WindowRowsAdjust"]))" "$((COLUMNS - DC["WindowColsAdjust"]))" | cut -d ' ' -f 1)"
        local -a SelectedAppsDialog=(
            "${SelectedAppsDialogParams[@]}"
            --ok-label "Done"
            --cancel-label "Cancel"
            --separate-output
            --checklist
            "${SelectAppsDialogText}"
            "$((LINES - DC["WindowRowsAdjust"]))" "$((COLUMNS - DC["WindowColsAdjust"]))"
            "$((LINES - DC["TextRowsAdjust"] - MenuTextLines))"
            "${AppList[@]}"
        )
        SelectedAppsDialogButtonPressed=0
        SelectedApps=$(_dialog_ "${SelectedAppsDialog[@]}") || SelectedAppsDialogButtonPressed=$?
    fi
    case ${DIALOG_BUTTONS[SelectedAppsDialogButtonPressed]-} in
        OK)
            local AppsToAdd AppsToRemove
            AppsToRemove=$(printf '%s\n' "${AddedApps[@]}" "${SelectedApps[@]}" "${SelectedApps[@]}" | tr ' ' '\n' | sort -f | uniq -u | xargs)
            AppsToAdd=$(printf '%s\n' "${AddedApps[@]}" "${AddedApps[@]}" "${SelectedApps[@]}" | tr ' ' '\n' | sort -f | uniq -u | xargs)
            local Heading=''
            local HeadingRemove
            local HeadingAdd
            if [[ -n ${AppsToAdd-} || -n ${AppsToRemove-} ]]; then
                if [[ -n ${AppsToAdd-} ]]; then
                    local FormattedAppList
                    local HeadingAddCommand=' ds --add '
                    local Indent='          '
                    FormattedAppList="$(printf "${Indent}%s\n" "${AppsToAdd}" | fmt -w "${COLUMNS}")"
                    HeadingAdd="Adding applications:\n${DC[CommandLine]}${HeadingAddCommand}${FormattedAppList:${#Indent}}\n"
                fi
                if [[ -n ${AppsToRemove-} ]]; then
                    local HeadingRemoveCommand=' ds --remove '
                    local Indent='             '
                    FormattedAppList="$(printf "${Indent}%s\n" "${AppsToRemove}" | fmt -w "${COLUMNS}")"
                    HeadingRemove="${DC[Subtitle]}Removing applications:\n${DC[CommandLine]}${HeadingRemoveCommand}${FormattedAppList:${#Indent}}\n"
                fi
                Heading="${HeadingAdd-}${HeadingRemove-}"
                {
                    run_script 'env_backup'
                    if [[ -n ${AppsToAdd-} ]]; then
                        notice "Creating variables for selected apps."
                        run_script 'appvars_create' "${AppsToAdd}"
                    fi
                    if [[ -n ${AppsToRemove-} ]]; then
                        notice "Removing variables for deselected apps."
                        run_script 'appvars_purge' "${AppsToRemove}"
                    fi
                    notice "Updating variable files"
                    run_script 'env_sanitize'
                    run_script 'env_update'
                } |& dialog_pipe "${DC[TitleSuccess]}Enabling Selected Applications" "${Heading}" "${DIALOGTIMEOUT}"
            fi
            return 0
            ;;
        CANCEL | ESC)
            return 1
            ;;
        *)
            if [[ -n ${DIALOG_BUTTONS[SelectedAppsDialogButtonPressed]-} ]]; then
                fatal "Unexpected dialog button '${DIALOG_BUTTONS[SelectedAppsDialogButtonPressed]}' pressed in menu_app_select."
            else
                fatal "Unexpected dialog button value '${SelectedAppsDialogButtonPressed}' pressed in menu_app_select."
            fi
            ;;
    esac
}

test_menu_app_select() {
    # run_script 'menu_app_select'
    warn "CI does not test menu_app_select."
}
