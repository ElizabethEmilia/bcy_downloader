# BCY Downloader

## Usage

```
usage: download.sh [-fhnvy] [--name name] [--ln name] url

Positional Arguments:
    url               An ALBUM URL or a COSER HOMEPAGE URL
                      ALBUM URL denotes to a single album 
                           (i.e., https://bcy.net/item/detail/6978776749035232294)
                      COSER HOMEPAGE URL denotes to the homepage of a coser, 
                           containes multiply albums (i.e., https://bcy.net/u/2437640)
Arguments:
    -f, --force       Force re-download if the album already exists without prompt
    -h, --help        Print this help message and exit
    -n                Do not re-download if the album already exists without prompt
        --name <name> Specify a name of directory name instead of using album ID as 
                      directory name
        --ln <name>   Specify a name of directory, which is linked to the original 
                      album directory
    -v, --version     Print version and license and exit
    -y                An alias for -f
```

For example:
```
$ ./download.sh https://bcy.net/item/detail/6978776749035232294
```
