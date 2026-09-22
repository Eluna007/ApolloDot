#!/usr/bin/env bash

# Shared XDG namespace for source-tree utility scripts.

apollo_paths_init() {
    local apollo_home=${HOME:?HOME must be set}
    local config_base=${XDG_CONFIG_HOME:-$apollo_home/.config}
    local data_base=${XDG_DATA_HOME:-$apollo_home/.local/share}
    local state_base=${XDG_STATE_HOME:-$apollo_home/.local/state}
    local cache_base=${XDG_CACHE_HOME:-$apollo_home/.cache}
    local runtime_base=${XDG_RUNTIME_DIR:-$cache_base/runtime}

    APOLLO_CONFIG_HOME=${APOLLO_CONFIG_HOME:-$config_base/apollo}
    APOLLO_DATA_HOME=${APOLLO_DATA_HOME:-$data_base/apollo}
    APOLLO_STATE_HOME=${APOLLO_STATE_HOME:-$state_base/apollo}
    APOLLO_CACHE_HOME=${APOLLO_CACHE_HOME:-$cache_base/apollo}
    APOLLO_RUNTIME_HOME=${APOLLO_RUNTIME_HOME:-$runtime_base/apollo}
    APOLLO_PROFILE=${APOLLO_PROFILE:-default}
    APOLLO_PROFILE_CONFIG_HOME=${APOLLO_PROFILE_CONFIG_HOME:-$APOLLO_CONFIG_HOME/profiles/$APOLLO_PROFILE}
    APOLLO_PROFILE_HOME=${APOLLO_PROFILE_HOME:-$APOLLO_DATA_HOME/profiles/$APOLLO_PROFILE}
    APOLLO_GENERATED_HOME=${APOLLO_GENERATED_HOME:-$APOLLO_PROFILE_HOME/generated}

    export APOLLO_CONFIG_HOME APOLLO_DATA_HOME APOLLO_STATE_HOME
    export APOLLO_CACHE_HOME APOLLO_RUNTIME_HOME APOLLO_PROFILE
    export APOLLO_PROFILE_CONFIG_HOME APOLLO_PROFILE_HOME APOLLO_GENERATED_HOME
}
