#! /bin/bash
# define commonly used functions

function get_pol ()
# function for extracting polarization string
# assumes the typical file format, and keys in on pattern "zen.xxxxxxx.xxxxx.pp.*",
# returns "pp"
{
    local pol=$(echo $1 | sed -E 's/zen\.[0-9]{7}\.[0-9]{5}\.(..)\..*$/\1/')
    echo "$pol"
}

function remove_pol ()
# function for getting the filename with the polarization string removed
{
    local pol=$(get_pol $1)
    local fn=$(echo $1 | sed -E "s/\.${pol}\././")
    echo $fn
}

function join_by ()
# function for concatenating strings
# from https://stackoverflow.com/questions/1527049/join-elements-of-an-array
# example syntax: (join_by , a b c) -> a,b,c
{
    local IFS="$1"; shift; echo "$*";
}

function is_lin_pol ()
# takes in a file name, and returns 0 if a linear polarization
# (e.g., 'xx'), and 1 if not
{
    local pol=$(get_pol $1)
    if [ ${pol:0:1} == ${pol:1:1} ]; then
        return 0
    else
        return 1
    fi
}

function is_same_pol ()
# takes in a file name, and returns 0 if it matches 2nd argument
# designed to be used to single out particular polarization
{
    local pol=$(get_pol $1)
    if [ ${pol} == $2 ]; then
        return 0
    else
        return 1
    fi
}

function replace_pol ()
# feed in a file name and a polarization, and replace the
# polarization with the provided one
{
    local pol=$(get_pol $1)
    local new_fn=$(echo $1 | sed -E "s/$pol/$2/")
    echo "$new_fn"
}

function get_jd ()
# function for extracting Julian date (JD) from filename
# assumes the typical file format, and keys in on pattern "zen.xxxxxxx.xxxxx.*"
# returns "xxxxxxx.xxxxx" as a string
{
    local jd=$(echo $1 | sed -E 's/zen\.([0-9]{7}\.[0-9]{5})\..*$/\1/')
    echo "$jd"
}

function get_gps ()
# function for extracting GPS time from filename
{
    local gps=$(echo $1 | sed -E 's/([0-9]{10})\..*$/\1/')
    echo "$gps"
}

function get_int_jd ()
# function for extracting just the integer portion of the Julian date (JD) from the filename
# assumes the typical file format, and keys in on pattern "zen.xxxxxxx.*"
# returns "xxxxxxx" (e.g., 2458000) as a string
{
    local jd=$(echo $1 | sed -E 's/zen\.([0-9]{7})\..*$/\1/')
    echo "$jd"
}

function prep_exants ()
# take in an ex_ants file, which has one "bad antenna" per line,
# and convert to a comma-separated list
# taken from https://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed
{
    local csl=$(cat $1 | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g')
    echo "$csl"
}

function query_exants_db ()
# use hera_mc to get a list of "dubitible" antennas from cm database
{
    local exants=`python -c "from hera_mc import sys_handling; H = sys_handling.Handling(); print H.get_dubitable_list()"`
    echo "$exants"
}

function inject_hh ()
{
  local fn_hh=`basename $1 | sed -E "s/(zen\.[0-9]{7}\.[0-9]{5}\.)/\1HH./g"`
  echo "$fn_hh"
}

function inject_diff ()
{
  local fn_diff=`basename $1 | sed -E "s/\.sum\./.diff./g"`
  echo "$fn_diff"
}

function stringContain()
# the following function was found from a stackoverflow thread
# want to find a substring inside of string and check the substring is not empty
# and the string is really a string
# https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
{
  [ -z "${2##*$1*}" ] && [ -z "$1" -o -n "$2" ];
}
