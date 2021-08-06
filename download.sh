#!/usr/bin/env bash

has_n_flag=0
has_y_flag=0

program_path=$0
program_name=$0
program_name=${program_name##*/}

ARG_LIST='[-fhnvy] url'

print_simple_help() {
    echo 'usage: '$program_name' '$ARG_LIST'
type "'$program_path' --help" for more information'
}

print_help() {
    echo 'usage: '$program_name' '$ARG_LIST'

Positional Arguments:
    url               The ALBUM URL or COSER HOMEPAGE URL
                      ALBUM URL denotes to a single album (i.e., https://bcy.net/item/detail/6978776749035232294)
                      COSER HOMEPAGE URL denotes to the homepage of a coser, containes multiply albums (i.e., https://bcy.net/u/2437640)

Arguments:
    -f    --force     Force re-download if the album already exists without prompt
    -h    --help      Print this help message and exit
    -n                Do not re-download if the album already exists without prompt
    -v    --version   Print version and license and exit
    -y                An alias for -f
   '
}

print_version() {
    echo 'Version: 1.0.0'
    echo 'REPOSITORY: https://github.com/ElizabethEmilia/bcy_downloader'
    echo 'Licensed under GNU General Public License (Version 3)'
}

require_a_positional_arg=0
current_proc_flag=

process_flag() {
    if [ $require_a_positional_arg -eq 1 ]; then
        if [ ${#current_proc_flag} -eq 1 ] ; then prefix='-'; else prefix='--'; fi
        echo "$program_name: expected an argument for : $prefix$flag"
    fi

    flag=$1
    current_proc_flag=$1
    require_a_positional_arg=0
    #echo "Processing: "$flag
    if [ $flag == 'n' ] ; then
        has_n_flag=1
        return 0
    elif [ $flag == 'y' ] || [ $flag == 'f' ] || [ $flag == 'force' ]; then
        has_y_flag=1
        return 0
    elif [ $flag == 'v' ] || [ $flag == 'version' ] ; then
        print_version
        exit 0
    elif [ $flag == 'h' ] || [ $flag == 'help' ]; then
        print_help
        exit 0
    else
        if [ ${#flag} -eq 1 ] ; then 
            prefix='-'
        else 
            prefix='--'
        fi
        echo "$program_name: unexpected argument: $prefix$flag"
        print_simple_help
        exit 1
    fi
}

process_flag_with_arg() {
    flag=$current_proc_flag
    arg=$1

    # process augumented flag
    # if [ $flag == 'xxx' ]; then ARG_FOR_XXX=$arg ; fi
}

process_positional_args() {
    index=$1
    arg=$2
    if [ $require_a_positional_arg -eq 1 ]; then
        process_flag_with_arg "$arg"
        return 0
    fi
    if [ $index -eq 0 ] ; then
        url="$arg"
    else
        echo "$program_name: unexpected positional argument: '$arg'"
        print_simple_help
        exit 1
    fi
}

pos_arg_index=0
for s in "$@" ; do
    if [ ${s:0:1} == '-' ] ; then
        # is flag
        if [ ! ${s:1:1} == '-' ] ; then
            # if is single flag
            slen=${#s}
            for i in $(seq 1 $(($slen-1))) ; do
                process_flag ${s:$i:1}
            done
        else
            # if is word flag
            process_flag ${s:2}
        fi
    else
        process_positional_args $pos_arg_index $s
        if [ $require_a_positional_arg -eq 0 ]; then
            pos_arg_index=$((pos_arg_index+1))
        fi
    fi
done
if [ $pos_arg_index -eq 0 ]; then
    echo "$program_name: missing required positional argument: url"
    print_simple_help
    exit 1
fi

if [ $(id -u) -eq 0 ] ; then
    echo "Do not run this application as root."
    exit 9
fi

r=""
fetch_content() {
    url=$1
    USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.164 Safari/537.36"
    COOKIES=""
    COOKIES_FILE=".cookies"
    if [ -f $COOKIES_FILE ] ; then
        echo "Using cookies from file '$COOKIES_FILE'.";
        COOKIES=$(cat $COOKIES_FILE | tr -d '\n')
    fi
    
    echo "Fetching information from $1"
    echo "Cookie: $COOKIES"
    r=$(curl "$url" -H "User-Agent: $USER_AGENT" -H "Cookie: $COOKIES")
    if [ ! $? -eq 0 ] ; then
        echo "Aborted. Couldn't fetch content from $url";
        exit 7
    fi
}

download_from_list() {
    img_list="$1"
    for image in $img_list
    do 
        image=$(sed "s/\\\\u002F/\\//g" <<< "$image")
        image=$(echo "$image"|tr -d '\\')
        save_to="$filename_base/$index.jpg"
        echo "Downloading image($index/$n_images): $image"
        echo "Save to: $save_to"
        curl "$image" --output "$save_to" -H "User-Agent: $USER_AGENT" -H "Cookie: $COOKIES"
        index=$(($index+1))
    done
}

download_album() {
    ## download main page
    fetch_content "$1"

    #download pictures
    index=1

    username=$(echo $r|grep -oE '<div class="user-name"><a class="cut" href=".*?" title=".*?">.*?</a></div>'|grep -oEi 'title=".*?"'|grep -oEi '".*?"'|tr -d '"'|head -1)
    album_id=$(echo "$url"|grep -oEi "\d+")
    filename_base="./$username/$album_id"
    echo "User Name: $username"
    echo "Saving to: $filename_base"

    if [ -d $filename_base ] ; then
        ans=""
        if [ $has_n_flag -eq 1 ]; then
            ans="n"
            echo "Album $filename_base already exists."
        elif [ $has_y_flag -eq 1 ]; then
            ans="y"
        fi
        while [ ! "$ans" = y ] && [ ! "$ans" = Y ] && [ ! "$ans" = n ] && [ ! "$ans" = N ] ;
        do
            printf "Album $filename_base already exists, redownload? (y/n):"
            read ans 
        done

        if [ "$ans" = y ] || [ "$ans" = Y ] ; then
            rm -rf "$filename_base"
        else
            return 0
        fi
    fi

    mkdir -p "$filename_base"

    ## parsing image list
    ##   - try with pattern 1
    image_list=$(echo $r|grep -oEi "https:\\\\.*?%3D"|grep -oEi "ratio.*?%3D"|grep -oEi "https:\\\\.*?%3D")
    n_images=$(echo "$image_list"|wc -l|tr -d '\t'|tr -d " "|bc)
    download_from_list "$image_list"
    ##   - try with pattern 2
    if [ $index -eq 1 ] ; then
        image_list=$(echo $r|grep -oEi "https.*?noop\.image"|grep -oEi "original_path.*?noop\.image"|grep -oEi "https.*?noop\.image")
        n_images=$(echo "$image_list"|wc -l|tr -d '\t'|tr -d " "|bc)
        download_from_list "$image_list"
    fi

    if [ $index -eq 1 ] ; then
        echo "No pictures have been found. It may because some authors require her photos to be visible after logging in. In this case, please log in to the \"banciyuan\" website on your browser first, and then copy the cookies after logging in. Then create a new file named $COOKIES_FILE locally, and paste the copied cookie in the file, and try to download it again."
        rm -rf "$filename_base/"
        return 1
    fi

    return 0
}

download_coser() {
    # download homepage
    fetch_content "$1"
    ret=1
    # get album list
    album_list=$(echo "$r"|grep -oEi '\\"item_id\\":\\".*?\\"'|grep -oEi "\d+")
    n_albums=$(echo "$album_list"|wc -l|tr -d '\t'|tr -d " "|bc)
    echo "Found $n_albums albums"
    album_i=1
    for album in $album_list ;
    do
        echo "Downloading album ($album_i/$n_albums): $album"
        album_url="https://bcy.net/item/detail/$album"
        download_album "$album_url"
        dl_result=$?
        dl_result=$(( ! $dl_result ))
        ret=$(($ret||$dl_result))
        album_i=$((  $album_i+1 ))
    done
    return $ret
}

URL="$url"
IS_DOWNLOADABLE=0
# check whether is album url or coser url
#   - if is album url
echo "$URL"|grep "//bcy.net/item/detail/" >/dev/null
if [ $? -eq 0 ] ; then
    echo "The url is an ablum page."
    IS_DOWNLOADABLE=1
    download_album "$URL"
    ret=$?
    exit $ret
fi
#   - if is the coser mainpage url
echo "$URL"|grep "//bcy.net/u/" >/dev/null
if [ $? -eq 0 ] ; then
    echo "The url is a coser homepage."
    IS_DOWNLOADABLE=1
    download_coser "$URL"
    ret=$?
    if [ $ret -eq 0 ] ; then
        echo "Not all album download completed!"
    fi
    exit $ret
fi
#   - otherwise
if [ $IS_DOWNLOADABLE -eq 0 ] ; then
    echo "Unable to download. The url is neither a coser mainpage, nor an album page."
    exit 5
fi
