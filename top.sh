#!/bin/bash

function remove_quotes() {
    echo `sed -e 's/^"//' -e 's/"$//' <<< $1`
}

function get_user_rank_in_artist() {
    for i in `seq 1 9`; do
        URL='https://www.last.fm'$1'/+listeners?page='$i
        LISTENERS=`curl -s $URL | pup '.top-listeners-item-name > a json{}'`
        POS=`echo $LISTENERS | jq '[.[].text] | index("'$2'")'`
        if [ "$POS" != "null" ]; then
            echo $((($POS + 1) * $i))
            exit 1
        fi
    done
}

function build_final() {
    echo "$1 - $2"
}

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
ENV_FILE="$SCRIPT_DIR/.env"

USER_RAW=`cat $ENV_FILE | jq '.user'`
USER=$(remove_quotes $USER_RAW)
TOTAL_ARTISTS=`cat $ENV_FILE | jq '.topArtists'`
EXTRA_ARTISTS=`cat $ENV_FILE | jq '.extraArtists'`

ARTISTS_RAW=[]
if [ $TOTAL_ARTISTS != 0 ]; then
    # Pega os top artistas do profile
    ARTISTS_RAW=`curl -s 'https://www.last.fm/user/'$USER'/library/artists' | pup -i 4 '.chartlist-name a json{}'`
fi
ARTISTS_RAW=`echo $ARTISTS_RAW | jq "[limit($TOTAL_ARTISTS;.[])] + $EXTRA_ARTISTS"`

TOTAL_ARTISTS=`echo $ARTISTS_RAW | jq 'length'`

for ((i=0; i<$TOTAL_ARTISTS; i++)); do
    ARTIST_NAME=`echo $ARTISTS_RAW | jq '.['$i'] | .title'`
    ARTIST_LINK=`echo $ARTISTS_RAW | jq '.['$i'] | .href'`
    USER_RANK=$(get_user_rank_in_artist $(remove_quotes $ARTIST_LINK) $USER)
    build_final "$ARTIST_NAME" $USER_RANK
done
