#!/bin/bash

echo -e "\n"

DATETIME=$(date +%Y-%m-%d\ %H:%M:%S)

function remove_quotes() {
    echo `sed -e 's/^"//' -e 's/"$//' <<< $1`
}

function read_previous_rank() {
    if [ -f $1 ]; then
        echo `cat $1`
    else
        echo ""
    fi
}

function read_previous_rank_in_artist() {
    if [ "$1" == "" ]; then
        echo 0
    fi
    local PREVIOUS_RANK=$(echo $1 | jq ".artists | unique_by(.artist) |.[] | select(.artist == $2) | .rank")
    echo $PREVIOUS_RANK
}

function get_previous_page() {
    echo $((($1 + 29) / 30))
}

function get_artist_link() {
    local ARTIST_NAME=$1
    local ARTIST_LINK=`echo $ARTIST_NAME | jq '"/music/"+@uri'`
    echo $ARTIST_LINK
}

function get_user_rank_in_artist() {
    local PREVIOUS_PAGE=9
    if ! [ $3 = 0 ]; then
        PREVIOUS_PAGE=$3
    fi

    for page in $(seq $PREVIOUS_PAGE -1 1) $(seq $(($PREVIOUS_PAGE+1)) 9) ; do
        URL='https://www.last.fm'$1'/+listeners?page='$page
        RESPONSE=`curl -s $URL`
        if [ -z "$RESPONSE" ]; then
            continue
        fi
        LISTENERS=`echo $RESPONSE | pup '.top-listeners-item-name > a json{}'`
        POS=`echo $LISTENERS | jq '[.[].text] | index("'$2'")'`
        if [ "$POS" != "" ] && [ "$POS" != "null" ]; then
            echo $((($POS + 1) + (($page - 1) * 30)))
            exit 1
        fi
    done
    echo 0
}

function get_artist_info() {
    $ARTIST_LINK=$1
    URL='https://www.last.fm'$1
    ARTIST_INFO=`curl -s $URL | pup '..header-metadata-tnew-item json{}'`
    LISTNERS=`echo $ARTIST_INFO | jq -r '[
{title: "Listeners", value: (.[] | select(.children[0].text == "Listeners") | .children[1].children[0].children[0].text)}
] | .[] | "\(.title): \(.value)"'
    SCROBBLES=`echo $ARTIST_INFO | jq -r '[
{title: "Scrobbles", value: (.[] | select(.children[0].text == "Scrobbles") | .children[1].children[0].children[0].text)}
] | .[] | "\(.title): \(.value)"'
}

function build_final_rank() {
    local RANK=0
    if [ -n "$3" ]; then
        RANK=$3
    fi
    local PREVIOUS_RANK=0
    if [ -n "$4" ]; then
        PREVIOUS_RANK=$4
    fi

    echo `echo $1 | jq "[.[]] + [{ \"artist\": $2, \"rank\": $RANK, \"previousRank\": $PREVIOUS_RANK}]"`
}

function show_artist_rank() {
    local ARTIST_NAME=$(remove_quotes "$1")
    local USER_RANK=$2
    local PREVIOUS_RANK=0
    if [ -n "$3" ]; then
        PREVIOUS_RANK=$3
    fi
    ARTIST_NAME=$(echo $ARTIST_NAME | cut -c 1-30)
    printf "| \033[0;34m%-30s\033[0m | \033[0;32m%9s\033[0m | \033[0;31m%8s\033[0m |\n" "$ARTIST_NAME" "$USER_RANK" "$PREVIOUS_RANK"
}

function save_rank() {
    local PREVIOUS_DATE_TIME=""
    if [ -n "$2" ]; then
        PREVIOUS_DATE_TIME=$(remove_quotes "$2")
    fi

    echo $1 | jq "sort_by(.artist) | { \"changedDateTime\": \"$DATETIME\", \"previousDateTime\": \"$PREVIOUS_DATE_TIME\" , \"artists\": . }" > top.json
}

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
ENV_FILE="$SCRIPT_DIR/.env"
SAVED_RANK_FILE="$SCRIPT_DIR/top.json"

USER_RAW=`cat $ENV_FILE | jq '.user'`
USER=$(remove_quotes $USER_RAW)
TOTAL_ARTISTS_CONFIG=`cat $ENV_FILE | jq '.topArtists'`
EXTRA_ARTISTS=`cat $ENV_FILE | jq '.extraArtists | [{ "title": .[] }]'`

SAVED_RANK=$(read_previous_rank $SAVED_RANK_FILE)
PREVIOUS_DATE_TIME=$(echo $SAVED_RANK | jq '.changedDateTime')

ARTISTS=[]
if [ $TOTAL_ARTISTS_CONFIG != 0 ]; then
    ARTISTS=`curl -s 'https://www.last.fm/user/'$USER'/library/artists' | pup -i 4 '.chartlist-name a json{}'`
fi
ARTISTS=`echo $ARTISTS | jq "[limit($TOTAL_ARTISTS_CONFIG;.[])] + $EXTRA_ARTISTS | unique_by(.title)"`

TOTAL_ARTISTS=`echo $ARTISTS | jq 'length'`

if [ -n "$PREVIOUS_DATE_TIME" ]; then
    printf "\033[0;36m%-s\033[0m\n" "Última atualização: $PREVIOUS_DATE_TIME"
    echo -e "\n"
fi
printf "%-46s\n" "+-------------------------------------------------------+"
printf "| \033[0;34m%-30s\033[0m | \033[0;32m%9s\033[0m | \033[0;31m%8s\033[0m |\n" "Artista" "Top Atual" "Anterior"
printf "%-46s\n" "+-------------------------------------------------------+"
FINAL_RANK=[]
for ((i=0; i<$TOTAL_ARTISTS; i++)); do
    ARTIST_NAME=`echo $ARTISTS | jq '.['$i'] | .title'`
    ARTIST_LINK=`echo $ARTISTS | jq '.['$i'] | .href'`
    if [ -z "$ARTIST_LINK" ] || [ "$ARTIST_LINK" == "null" ]; then
        ARTIST_LINK=$(get_artist_link "$ARTIST_NAME")
    fi
    PREVIOUS_RANK_IN_ARTIST=$(read_previous_rank_in_artist "$SAVED_RANK" "$ARTIST_NAME")
    PREVIOUS_PAGE=$(get_previous_page $PREVIOUS_RANK_IN_ARTIST)
    # echo $PREVIOUS_RANK_IN_ARTIST $PREVIOUS_PAGE
    USER_RANK=$(get_user_rank_in_artist $(remove_quotes $ARTIST_LINK) $USER $PREVIOUS_PAGE)
    show_artist_rank "$ARTIST_NAME" "$USER_RANK" "$PREVIOUS_RANK_IN_ARTIST"
    FINAL_RANK=$(build_final_rank "$FINAL_RANK" "$ARTIST_NAME" $USER_RANK $PREVIOUS_RANK_IN_ARTIST)
done
printf "%-46s\n" "+-------------------------------------------------------+"
save_rank "$FINAL_RANK" "$PREVIOUS_DATE_TIME"
