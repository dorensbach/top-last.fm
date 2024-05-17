#!/bin/bash

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

function get_user_rank_in_artist() {
    local PREVIOUS_PAGE=$3
    # cur=3 ; for page in $(seq $cur -1 1) $(seq $((cur+1)) 9) ; do echo $page ; done

    for i in `seq 1 9`; do
        URL='https://www.last.fm'$1'/+listeners?page='$i
        LISTENERS=`curl -s $URL | pup '.top-listeners-item-name > a json{}'`
        POS=`echo $LISTENERS | jq '[.[].text] | index("'$2'")'`
        if [ "$POS" != "null" ]; then
            echo $((($POS + 1) + (($i - 1) * 30)))
            exit 1
        fi
    done
}

function build_final_rank() {
    RANK=0
    if [ -n "$3" ]; then
        RANK=$3
    fi
    echo `echo $1 | jq "[.[]] + [{ \"artist\": $2, \"rank\": $RANK}]"`
}

function show_artist_rank() {
    echo -e "$1\t-\t$2"
}

function save_rank() {
    echo $1 | jq "sort_by(.artist) | { \"changedDateTime\": \"$DATETIME\", \"artists\": . }" > top.json
}

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
ENV_FILE="$SCRIPT_DIR/.env"
SAVED_RANK_FILE="$SCRIPT_DIR/top.json"

USER_RAW=`cat $ENV_FILE | jq '.user'`
USER=$(remove_quotes $USER_RAW)
TOTAL_ARTISTS=`cat $ENV_FILE | jq '.topArtists'`
EXTRA_ARTISTS=`cat $ENV_FILE | jq '.extraArtists'`

SAVED_RANK=$(read_previous_rank $SAVED_RANK_FILE)

ARTISTS=[]
if [ $TOTAL_ARTISTS != 0 ]; then
    ARTISTS=`curl -s 'https://www.last.fm/user/'$USER'/library/artists' | pup -i 4 '.chartlist-name a json{}'`
fi
ARTISTS=`echo $ARTISTS | jq "[limit($TOTAL_ARTISTS;.[])] + $EXTRA_ARTISTS | unique_by(.title)"`

TOTAL_ARTISTS=`echo $ARTISTS | jq 'length'`

# TOTAL_ARTISTS=2
FINAL_RANK=[]
for ((i=0; i<$TOTAL_ARTISTS; i++)); do
    ARTIST_NAME=`echo $ARTISTS | jq '.['$i'] | .title'`
    ARTIST_LINK=`echo $ARTISTS | jq '.['$i'] | .href'`
    PREVIOUS_RANK_IN_ARTIST=$(read_previous_rank_in_artist "$SAVED_RANK" "$ARTIST_NAME")
    PREVIOUS_PAGE=$(get_previous_page $PREVIOUS_RANK_IN_ARTIST)
    # echo $PREVIOUS_RANK_IN_ARTIST $PREVIOUS_PAGE
    USER_RANK=$(get_user_rank_in_artist $(remove_quotes $ARTIST_LINK) $USER $PREVIOUS_PAGE)
    show_artist_rank "$ARTIST_NAME" "$USER_RANK"
    FINAL_RANK=$(build_final_rank "$FINAL_RANK" "$ARTIST_NAME" $USER_RANK)
done
save_rank "$FINAL_RANK"
