#!/bin/bash -e

if [ "$1" == "SQLRight" ]; then

    cd "$(dirname "$0")"/..

    if [ ! -d "./Results" ]; then
        echo "Results folder not existed. Please run the fuzzing process first. "
        exit 1
    fi

    if [ ! -d "./Uniq_Bugs" ]; then
        mkdir -p Uniq_Bugs
    fi

    resoutdir="sqlright_sqlite"
    for var in "$@"
    do
        if [ "$var" == "drop_all" ]; then
            resoutdir="$resoutdir""_drop_all"
        elif [ "$var" == "random_save" ]; then
            resoutdir="$resoutdir""_random_save"
        elif [ "$var" == "save_all" ]; then
            resoutdir="$resoutdir""_save_all"
        fi
    done

    for var in "$@"
    do
        if [ "$var" == "NOREC" ]; then
            resoutdir="$resoutdir""_NOREC"
        elif [ "$var" == "TLP" ]; then
            resoutdir="$resoutdir""_TLP"
        fi
    done

    bugoutdir="$resoutdir""_bugs"

    if [ ! -d "./Results/$bugoutdir" ]; then
        echo "Detected Results/$bugoutdir folder not existed. Please run the fuzzing to generate the bug reports first. "
        exit 5
    fi

    if [ -d "./Uniq_Bugs/$bugoutdir" ]; then
        echo "Detected Uniq_Bugs/$bugoutdir folder existed. Please clean up the Uniq_Bugs/$bugoutdir folder before running the bisecting command. "
        exit 5
    fi

    mkdir -p $(pwd)/Uniq_Bugs/$bugoutdir

    sudo docker run -i \ # --rm \ # Remove --rm, the generated container can be used for further binary saving. 
        -v $(pwd)/Results/$bugoutdir:/home/sqlite/bisecting/bug_samples \
        -v $(pwd)/Uniq_Bugs/$bugoutdir:/home/sqlite/bisecting/unique_bug_output  \
        sqlright_sqlite /bin/bash /home/sqlite/scripts/run_bisecting_helper.sh ${@:2}

elif [ "$1" == "no-ctx-valid" ]; then

    cd "$(dirname "$0")"/..

    if [ ! -d "./Results" ]; then
        echo "Results folder not existed. Please run the fuzzing process first. "
        exit 1
    fi

    if [ ! -d "./Uniq_Bugs" ]; then
        mkdir -p Uniq_Bugs
    fi

    resoutdir="sqlright_sqlite_no_ctx_valid"
    for var in "$@"
    do
        if [ "$var" == "drop_all" ]; then
            resoutdir="$resoutdir""_drop_all"
        elif [ "$var" == "random_save" ]; then
            resoutdir="$resoutdir""_random_save"
        elif [ "$var" == "save_all" ]; then
            resoutdir="$resoutdir""_save_all"
        fi
    done

    for var in "$@"
    do
        if [ "$var" == "NOREC" ]; then
            resoutdir="$resoutdir""_NOREC"
        elif [ "$var" == "TLP" ]; then
            resoutdir="$resoutdir""_TLP"
        fi
    done

    bugoutdir="$resoutdir""_bugs"

    if [ ! -d "./Results/$bugoutdir" ]; then
        echo "Detected Results/$bugoutdir folder not existed. Please run the fuzzing to generate the bug reports first. "
        exit 5
    fi

    if [ -d "./Uniq_Bugs/$bugoutdir" ]; then
        echo "Detected Uniq_Bugs/$bugoutdir folder existed. Please clean up the Uniq_Bugs/$bugoutdir folder before running the bisecting command. "
        exit 5
    fi

    mkdir -p $(pwd)/Uniq_Bugs/$bugoutdir

    sudo docker run -i \ # --rm \ # Remove --rm, the generated container can be used for further binary saving. 
        -v $(pwd)/Results/$bugoutdir:/home/sqlite/bisecting/bug_samples \
        -v $(pwd)/Uniq_Bugs/$bugoutdir:/home/sqlite/bisecting/unique_bug_output  \
        sqlright_sqlite /bin/bash /home/sqlite/scripts/run_bisecting_helper.sh ${@:2}

elif [ "$1" == "no-db-par-ctx-valid" ]; then

    cd "$(dirname "$0")"/..

    if [ ! -d "./Results" ]; then
        echo "Results folder not existed. Please run the fuzzing process first. "
        exit 1
    fi

    if [ ! -d "./Uniq_Bugs" ]; then
        mkdir -p Uniq_Bugs
    fi

    resoutdir="sqlright_sqlite_no_db_par_ctx_valid"
    for var in "$@"
    do
        if [ "$var" == "drop_all" ]; then
            resoutdir="$resoutdir""_drop_all"
        elif [ "$var" == "random_save" ]; then
            resoutdir="$resoutdir""_random_save"
        elif [ "$var" == "save_all" ]; then
            resoutdir="$resoutdir""_save_all"
        fi
    done

    for var in "$@"
    do
        if [ "$var" == "NOREC" ]; then
            resoutdir="$resoutdir""_NOREC"
        elif [ "$var" == "TLP" ]; then
            resoutdir="$resoutdir""_TLP"
        fi
    done

    bugoutdir="$resoutdir""_bugs"

    if [ ! -d "./Results/$bugoutdir" ]; then
        echo "Detected Results/$bugoutdir folder not existed. Please run the fuzzing to generate the bug reports first. "
        exit 5
    fi

    if [ -d "./Uniq_Bugs/$bugoutdir" ]; then
        echo "Detected Uniq_Bugs/$bugoutdir folder existed. Please clean up the Uniq_Bugs/$bugoutdir folder before running the bisecting command. "
        exit 5
    fi

    mkdir -p $(pwd)/Uniq_Bugs/$bugoutdir

    sudo docker run -i \ # --rm \ # Remove --rm, the generated container can be used for further binary saving. 
        -v $(pwd)/Results/$bugoutdir:/home/sqlite/bisecting/bug_samples \
        -v $(pwd)/Uniq_Bugs/$bugoutdir:/home/sqlite/bisecting/unique_bug_output  \
        sqlright_sqlite /bin/bash /home/sqlite/scripts/run_bisecting_helper.sh ${@:2}

elif [ "$1" == "squirrel-oracle" ]; then

    cd "$(dirname "$0")"/..

    if [ ! -d "./Results" ]; then
        echo "Results folder not existed. Please run the fuzzing process first. "
        exit 1
    fi

    if [ ! -d "./Uniq_Bugs" ]; then
        mkdir -p Uniq_Bugs
    fi

    resoutdir="squirrel_oracle"
    for var in "$@"
    do
        if [ "$var" == "drop_all" ]; then
            resoutdir="$resoutdir""_drop_all"
        elif [ "$var" == "random_save" ]; then
            resoutdir="$resoutdir""_random_save"
        elif [ "$var" == "save_all" ]; then
            resoutdir="$resoutdir""_save_all"
        fi
    done

    for var in "$@"
    do
        if [ "$var" == "NOREC" ]; then
            resoutdir="$resoutdir""_NOREC"
        elif [ "$var" == "TLP" ]; then
            resoutdir="$resoutdir""_TLP"
        fi
    done

    bugoutdir="$resoutdir""_bugs"

    if [ ! -d "./Results/$bugoutdir" ]; then
        echo "Detected Results/$bugoutdir folder not existed. Please run the fuzzing to generate the bug reports first. "
        exit 5
    fi

    if [ -d "./Uniq_Bugs/$bugoutdir" ]; then
        echo "Detected Uniq_Bugs/$bugoutdir folder existed. Please clean up the Uniq_Bugs/$bugoutdir folder before running the bisecting command. "
        exit 5
    fi

    mkdir -p $(pwd)/Uniq_Bugs/$bugoutdir

    sudo docker run -i \ # --rm \ # Remove --rm, the generated container can be used for further binary saving. 
        -v $(pwd)/Results/$bugoutdir:/home/sqlite/bisecting/bug_samples \
        -v $(pwd)/Uniq_Bugs/$bugoutdir:/home/sqlite/bisecting/unique_bug_output  \
        sqlright_sqlite /bin/bash /home/sqlite/scripts/run_bisecting_helper.sh ${@:2}

else
    echo "Usage: bash bisecting_sqlite_bugs.sh <config> -O <oracle> [-F <feedback>] "
fi
