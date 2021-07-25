if [ ! $# -eq 1 ] ; then
    echo "usage: $0 <url>"
    echo ""
    echo "Note: the url is the album URL, which is like 'https://bcy.net/item/detail/6951189355700427780'."
    exit 1
fi

url=$1
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.164 Safari/537.36"
COOKIES=""
COOKIES_FILE=".cookies"
if [ -f $COOKIES_FILE ] ; then
    echo "Using cookies from file '$COOKIES_FILE'.";
    COOKIES=$(cat $COOKIES_FILE | tr -d '\n')
fi

## download main page
echo "Fetching information from $1"
echo "Cookie: $COOKIES"
r=$(curl "$url" -H "User-Agent: $USER_AGENT" -H "Cookie: $COOKIES")
username=$(echo $r|grep -oE '<div class="user-name"><a class="cut" href=".*?" title=".*?">.*?</a></div>'|grep -oEi 'title=".*?"'|grep -oEi '".*?"'|tr -d '"'|head -1)
album_id=$(echo "$url"|grep -oEi "\d+")
filename_base="$username/$album_id"

echo "User Name: $username"
echo "Saving to: $filename_base"

#download pictures
index=1

if [ -d $filename_base ] ; then
    ans=""
    while [ ! "$ans" = y ] && [ ! "$ans" = Y ] && [ ! "$ans" = n ] && [ ! "$ans" = N ] ;
    do
        printf "Album $filename_base already exists, redownload? (y/n):"
        read ans 
    done

    if [ "$ans" = y ] || [ "$ans" = Y ] ; then
        rm -rf "./$filename_base"
    else
        exit 0
    fi
fi

mkdir -p "$filename_base"

download_from_list() {
    img_list="$1"
    for image in $img_list
    do 
        image=$(sed "s/\\\\u002F/\\//g" <<< "$image")
        save_to="$filename_base/$index.jpg"
        echo "Downloading image($index/$n_images): $image"
        echo "Save to: $save_to"
        curl "$image" --output "$save_to" -H "User-Agent: $USER_AGENT" -H "Cookie: $COOKIES"
        index=$(($index+1))
    done
}

## parsing image list
##   - try with pattern 1
image_list=$(echo $r|grep -oEi "https:\\\\.*?%3D"|grep -oEi "ratio.*?%3D"|grep -oEi "https:\\\\.*?%3D")
n_images=$(echo "$image_list"|wc -l|tr -d '\t'|tr -d " "|bc)
download_from_list "$image_list"
##   - try with pattern 2
if [ $index -eq 1 ] ; then
    image_list=$(echo $r|grep -oEi "https.*?noop\.image"|grep -oEi "mid.*?noop\.image"|grep -oEi "https.*?noop\.image")
    n_images=$(echo "$image_list"|wc -l|tr -d '\t'|tr -d " "|bc)
    download_from_list "$image_list"
fi

if [ $index -eq 1 ] ; then
    echo "No pictures have been found. It may because some authors require her photos to be visible after logging in. In this case, please log in to the \"banciyuan\" website on your browser first, and then copy the cookies after logging in. Then create a new file named $COOKIES_FILE locally, and paste the copied cookie in the file, and try to download it again."
    rm -rf "$filename_base/"
    exit 2
fi
