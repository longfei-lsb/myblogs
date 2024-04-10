#!/bin/bash
IFS=$(echo -en "\n\b")
function getdir(){
    size=2 # 设置字体大小
    for element in `ls -1 $1`
    do
        dir_or_file=$1"/"$element
        counter=`echo $dir_or_file | grep -o / | wc -l`
        let size-=1
        if [ 2 -gt $size ] ;
        then
          size=3
        else
          echo ""
        fi
        let counter-=2
        if [ -d $dir_or_file ] ;
        then

            printf '%0.s  ' $(seq 0 $counter) >> _sidebar.md
            echo "- <font size = '$size'>$element</font>" >> _sidebar.md
            getdir $dir_or_file
        else
            echo $dir_or_file
            printf '%0.s  ' $(seq 0 $counter) >> _sidebar.md
            path=`echo $dir_or_file| sed "s/[ ]/%20/g" | sed "s/[+]/%2B/g"`
            title=`echo $element | sed "s/.md//"`
            echo "- [<font color = 'pink'>$title</font>](./$path)" >> _sidebar.md
        fi
    done
}

root_dir=`ls -d mynotes/*/`
#root_dir=`ls -d */ "$1/VulWiki" | sed 's/\///g'`
:> _sidebar.md
for dir in $root_dir
do
    if [ "$dir" = "." ]
    then
        continue
    else
        if [ "$dir" = "mynotes/公司/" ];
        then
            continue
        else
            C1=`echo $dir | cut -f2 -d '/'` # -f2：显示按照"/"分割后的第二个元素
            echo "- <font size = '3'>$C1</font>" >> _sidebar.md
            getdir `echo $dir | sed s'/.$//'`
        fi
    fi
done