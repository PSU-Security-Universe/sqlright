#!/bin/bash -e

if [ "$1" == "SQLRight" ]; then

    cd "$(dirname "$0")"/..

    if [ ! -d "./Results" ]; then
        mkdir -p Results
    fi

    resoutdir="sqlright_mysql"

    for var in "$@"
    do
        if [ "$var" == "NOREC" ]; then
            resoutdir="$resoutdir""_NOREC"
        elif [ "$var" == "TLP" ]; then
            resoutdir="$resoutdir""_TLP"
        fi
    done

    bugoutdir="$resoutdir""_bugs"

    cd Results

    if [ ! -d "./$bugoutdir" ]; then
        echo "Detected Results/$bugoutdir folder MISSING. Please run the fuzzing first to generate the bug output folder. "
        exit 5
    fi

    bugoutdir="$bugoutdir/bug_samples"
    resoutdir="$resoutdir""_bisecting"

    echo "Begin running bisecting. "
    sudo docker run -i --rm \
        -v $(pwd)/$bugoutdir:/home/mysql/bisecting_scripts/bug_samples \
        --name $resoutdir \
        sqlright_mysql_bisecting /bin/bash /home/mysql/scripts/run_mysql_bisecting_helper.sh ${@:2}

else
    echo "Wrong arguments: $@"
    echo "Usage: bash run_mysql_bisecting.sh <config> -O <oracle> "
fi
