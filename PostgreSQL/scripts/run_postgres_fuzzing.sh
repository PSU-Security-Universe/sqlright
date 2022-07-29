#!/bin/bash -e

if [ "$1" == "SQLRight" ]; then

    cd "$(dirname "$0")"/.. 
    
    if [ ! -d "./Results" ]; then
        mkdir -p Results
    fi

    resoutdir="sqlright_postgres"

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
    
    if [ -d "./$resoutdir" ]; then
        echo "Detected Results/$resoutdir folder existed. Please cleanup the output folder and then retry. "
        exit 5
    fi
    if [ -d "./$bugoutdir" ]; then
        echo "Detected Results/$bugoutdir folder existed. Please cleanup the output folder and then retry. "
        exit 5
    fi
    
    sudo docker run -i --rm \
        -v $(pwd)/$resoutdir:/home/postgres/fuzzing/fuzz_root/outputs \
        -v $(pwd)/$bugoutdir:/home/postgres/fuzzing/Bug_Analysis \
        --name $resoutdir \
        sqlright_postgres /bin/bash /home/postgres/scripts/run_sqlright_postgres_fuzzing_helper.sh ${@:2}
    
else
    echo "Usage: bash run_postgres_fuzzing.sh SQLRight --start-core <num> --num-concurrent <num> -O <oracle> "
fi
