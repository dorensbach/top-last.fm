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

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
ENV_FILE="$SCRIPT_DIR/.env"

USER_RAW=`cat $ENV_FILE | jq '.user'`
USER=$(remove_quotes $USER_RAW)
TOTAL_ARTISTS=`cat $ENV_FILE | jq '.topArtists'`
EXTRA_ARTISTS=`cat $ENV_FILE | jq '.extraArtists'`

ARTISTS=[]
if [ $TOTAL_ARTISTS != 0 ]; then
    ARTISTS=`curl -s 'https://www.last.fm/user/'$USER'/library/artists' | pup -i 4 '.chartlist-name a json{}'`
fi
ARTISTS=`echo $ARTISTS | jq "[limit($TOTAL_ARTISTS;.[])] + $EXTRA_ARTISTS"`

TOTAL_ARTISTS=`echo $ARTISTS | jq 'length'`

# FINAL_RANK=[]
for ((i=0; i<$TOTAL_ARTISTS; i++)); do
    ARTIST_NAME=`echo $ARTISTS | jq '.['$i'] | .title'`
    ARTIST_LINK=`echo $ARTISTS | jq '.['$i'] | .href'`
    USER_RANK=$(get_user_rank_in_artist $(remove_quotes $ARTIST_LINK) $USER)
    echo -e "$ARTIST_NAME\t-\t$USER_RANK"
    # FINAL_RANK=$(build_final_rank "$FINAL_RANK" "$ARTIST_NAME" $USER_RANK)
done
# echo -e $FINAL_RANK
