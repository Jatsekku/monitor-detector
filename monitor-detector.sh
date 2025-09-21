#!/bin/bash
set +o errexit

MONITOR_DETECTOR_SH="$(realpath "$0")"

readonly JSON_RULES_FILE="/etc/monitor-detector/rules.json"
readonly BASH_LOGGER_LOG_FILE="/etc/monitor-detector/monitor-detector.log"

# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}" 
logger_register_module "monitor-detector" "$LOG_LEVEL_DBG"
logger_set_log_file "$BASH_LOGGER_LOG_FILE"

__match_edid() {
    local -r edid_data="$1"
    local -r edid_pattern="$2"

    # Check if data string is empty
    if [[ -z "$edid_data" ]]; then
        log_wrn "EDID data is empty"
        return 2 # Empty data
    fi

    # Match against the pattern
    # shellcheck disable=SC2053
    if [[ "$edid_data" == $edid_pattern ]]; then
        return 0 # Matched
    else
        return 1 # Not matched
    fi
}

__run_callback() {
    local -r callback="$1"

    # Check if any non-white characters has been passed to function
    if [[ -z "${callback// /}" ]]; then
        log_err "No command or script provided"
        return 2 # No command/script
    fi

    # Split callback string into array (for possible file + args)
    read -r -a callback_parts <<< "$callback"

    # Check if it's executable file
    if [[ -f "${callback_parts[0]}" && -x "${callback_parts[0]}" ]]; then
        # It's executable
        local -r callback_file="${callback_parts[0]}"
        local -r callback_args_string="${callback_parts[*]:1}"
        local -r callback_args_array=("${callback_parts[@]:1}")

        local log_message="Callback is executable [${callback_file}]"
        log_message+=" with args [${callback_args_string}]"
        log_dbg "${log_message}"

        # Run executable with args
        "$callback_file" "${callback_args_array[@]}"
    else
        # It's bash command(s)
        local -r callback_commands=("${callback_parts[@]}")
        log_dbg "Callback is command(s)"
        bash -c "${callback_commands[*]}"
    fi
}

__get_device_status_by_edid() {
    local -r edid_pattern="$1"
    log_dbg "Checking DRM device [${edid_pattern}] presence..."

    # Loop through DRM devices
    for drm_device in /sys/class/drm/*; do
        # Get the path to edid file
        local edid_file="$drm_device/edid"

        # Skip if edid_file does not exist
        [[ -f "$edid_file" ]] || continue

        # Read the EDID data from the file and strip non-printable chars
        edid_data=$(tr -cd '[:print:]' < "$edid_file")

        # Skip if pattern does not match EDID content
        __match_edid "$edid_data" "$edid_pattern" || continue

        # Pattern matched
        log_dbg "Pattern [$edid_pattern] matched in [$drm_device]"

        # If EDID can be readout it means that device is already electrically connected
        log_dbg "DRM device [${edid_pattern}] is connected"
        return 0
    done

    log_dbg "DRM device [${edid_pattern}] is disconnected"
    return 1
}

__json_event2device_status() {
    local -r json_event="$1"

    case $json_event in
        attached) echo 0;;
        detached) echo 1;;
        *) echo 2;;
    esac
}

__handle_drm_event() {
    log_dbg "DRM change event occured"
    local -r json_file="$1"

    # json_file has to exist
    if [[ ! -f "$json_file" ]]; then
        log_err "JSON file [${json_file}] not found"
        return 2
    fi

    # Iterate over each rule
    jq -c '.[]' "$json_file" | while read -r rule; do
        event=$(jq -r '.event' <<< "$rule")
        callback=$(jq -r '.callback' <<< "$rule")
        pattern=$(jq -r '.pattern' <<< "$rule")

        log_dbg "Processing rule... event: [$event], pattern: [${pattern}]"

        # Get status by EDID
        __get_device_status_by_edid "$pattern"
        local device_status=$?

        expected_device_status=$(__json_event2device_status "$event")
        if [[ $device_status -eq $expected_device_status ]]; then
            device_status=$([[ $device_status -eq 0 ]] && echo "attached" || echo "detached")
            log_inf "DRM device [${pattern}] has been ${device_status}"
            __run_callback "$callback"
        fi
    done
}

__main() {
    __handle_drm_event "$JSON_RULES_FILE"
}

monitor_detector_udev_entry() {
    setsid bash -c "
        source '$BASH_LOGGER_SH'
        source '$MONITOR_DETECTOR_SH'
        logger_register_module 'monitor-detector-detached' '$LOG_LEVEL_DBG'
        logger_set_log_file '$BASH_LOGGER_LOG_FILE'
        __main
    "
}

# Run only if invoked directly - infinite recursion protection
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    monitor_detector_udev_entry
fi
