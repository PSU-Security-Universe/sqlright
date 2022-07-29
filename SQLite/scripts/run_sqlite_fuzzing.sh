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
    
    if [ -d "./$resoutdir" ]; then
        echo "Detected Results/$resoutdir folder existed. Please cleanup the output folder and then retry. "
        exit 5
    fi
    if [ -d "./$bugoutdir" ]; then
        echo "Detected Results/$bugoutdir folder existed. Please cleanup the output folder and then retry. "
        exit 5
    fi
    
    sudo docker run -i --rm \
        -v $(pwd)/$resoutdir:/home/sqlite/fuzzing/fuzz_root/outputs \
        -v $(pwd)/$bugoutdir:/home/sqlite/fuzzing/Bug_Analysis \
        --name $resoutdir \
        sqlright_sqlite /bin/bash /home/sqlite/scripts/run_sqlright_sqlite_fuzzing_helper.sh ${@:2}
    
else
    echo "Wrong arguments: $@"
    echo "Usage: bash run_sqlite_fuzzing.sh SQLRight --start-core <num> --num-concurrent <num> -O <oracle> "
fi
