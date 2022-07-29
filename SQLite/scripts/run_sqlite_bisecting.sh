#!/bin/bash -e

if [ "$1" == "SQLRight" ]; then

    cd "$(dirname "$0")"/.. 
    
    if [ ! -d "./Results" ]; then
        mkdir -p Results
    fi

    resoutdir="sqlright_sqlite"

    for var in "$@"
    do
        if [ "$var" == "NOREC" ]; then
            resoutdir="$resoutdir""_NOREC"
        elif [ "$var" == "TLP" ]; then
            resoutdir="$resoutdir""_TLP"
        elif [ "$var" == "LIKELY" ]; then
            resoutdir="$resoutdir""_LIKELY"
        elif [ "$var" == "ROWID" ]; then
            resoutdir="resoutdir""_ROWID"
        elif [ "$var" == "INDEX" ]; then
            resoutdir="resoutdir""_INDEX"
        fi
    done

    bugoutdir="$resoutdir""_bugs"
    
    cd Results
    
    if [ ! -d "./$bugoutdir" ]; then
        echo "Detected Results/$bugoutdir folder not existed. Please run the fuzzing first to generate the bug output folder. "
        exit 5
    fi

    bugoutdir="$bugoutdir/bug_samples"
    resoutdir="$resoutdir""_bisecting"
    
    echo "Begins to run bug bisecting. "
    sudo docker run -i --rm \
        -v $(pwd)/$bugoutdir:/home/sqlite/bisecting/bug_samples \
        --name $resoutdir \
        sqlright_sqlite /bin/bash /home/sqlite/scripts/run_sqlite_bisecting_helper.sh ${@:2}

else
    echo "Usage: bash run_sqlite_bisecting.sh SQLRight -O <oracle> "
fi
