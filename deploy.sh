#!/usr/bin/env bash

export DEPLOY_PATH=$PWD
export COMPOSE_IGNORE_ORPHANS=True

JOBS=()
JOBS+=("gps-tracker-migrator")
JOBS+=("gps-users-migrator")

PODS=()
PODS+=("gps-rabbitmq")
PODS+=("gps-tracker-mongo")
PODS+=("gps-tracker")
PODS+=("gps-users-postgres")
PODS+=("gps-gateway")
PODS+=("gps-users")

EXCLUDE_PODS=()
TO_RUN=()

podsCount="${#PODS[@]}"

PODS_COMPOSE_FILE=./pods/docker-compose.yaml

function runJob() {
    echo "***executing job $1***"
    echo

    docker-compose -f ./jobs/docker-compose.yaml up $1

    echo "done"
    echo

    sleep 1
}

function showHelp() {
    echo "Control of deploying process"
    echo
    echo "./deploy.sh [ down | up [flags] ]"
    echo
    echo "flags:"
    echo "-h, --help                show brief help"
    echo "-e, --exclude=PODNAME     exclude pod from deploying process"
    echo "-p                        only for down command; bring down only pods (without fabric)"

    exit 0
}

function up() {
    echo
    echo "***bring up pods***"
    echo

    cd $DEPLOY_PATH/

    excludeCount="${#EXCLUDE_PODS[@]}"

    if [ $excludeCount != '0' ]; then
        for i in "${PODS[@]}"; do
            skip=
            for j in "${EXCLUDE_PODS[@]}"; do
                [[ $i == $j ]] && { skip=1; break; }
            done
            [[ -n $skip ]] || TO_RUN+=("$i")
        done

        podsCount="${#TO_RUN[@]}"

        IFS=' '
        LIST="${TO_RUN[*]}"

        docker-compose -f $PODS_COMPOSE_FILE up -d $LIST
    else
        TO_RUN=PODS
        docker-compose -f $PODS_COMPOSE_FILE up -d
    fi

    echo
    echo "***check count of pods***"
    echo

    runnedPodsCount=$(docker-compose -f $PODS_COMPOSE_FILE ps -q | wc -l)

    if [ $runnedPodsCount != $podsCount ]; then
        echo
        echo "!!!!!!pods are not running correctly!!!!!!"
        echo

        for i in "${TO_RUN[@]}"; do
            isRun=$(docker-compose -f $PODS_COMPOSE_FILE ps -q | xargs docker inspect -f '{{ .Name }}' | grep "$i" | wc -l)

            if [ $isRun == '0' ]; then
                echo "$i is not running"
            fi
        done

        exit 1
    fi

    echo "---valid count---"

    echo
    echo "***check exited pods***"
    echo

    exitedPodsCount=$(docker-compose -f $PODS_COMPOSE_FILE ps -q | xargs docker inspect -f '{{ .State.Pid }}' | grep '^0$' | wc -l | tr -d ' ')

    if [ $exitedPodsCount != '0' ]; then
        echo
        echo "!!!!!!some pods are exited!!!!!!"
        echo

        for i in "${TO_RUN[@]}"; do
            isExited=$(docker-compose -f $PODS_COMPOSE_FILE ps -q | xargs docker inspect -f '{{ .Name }}' | grep "$i" | xargs docker inspect -f '{{ .State.Pid }}' | grep '^0$' | wc -l | tr -d ' ')

            if [ $isExited == '1' ]; then
                echo "$i is exited"
            fi
        done

        exit 1
    fi

    echo "---have not exited---"

    echo
    echo "***execute jobs***"
    echo

    for i in "${!JOBS[@]}"
    do
        JOB_NAME=${JOBS[${i}]}

        runJob $JOB_NAME
    done

    exit 0
}

ONLY_PODS=false

function down() {
    cd $DEPLOY_PATH/

    docker-compose -f $PODS_COMPOSE_FILE down
    docker-compose -f ./jobs/docker-compose.yaml down

    exit 0
}

COMMAND=""

while test $# -gt 0; do
    case "$1" in
        -e|--exclude)
            shift
            if test $# -gt 0; then
                EXCLUDE_PODS+=($1)
            fi
            shift
            ;;
        -p)
            shift
            ONLY_PODS=true
            ;;
        up)
            COMMAND="up"
            shift
            ;;
        down)
            COMMAND="down"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$COMMAND" == "" ]]; then
    showHelp
else
    case $COMMAND in
    "up")
        up
        ;;

    "down")
        down
        ;;

    *)
        showHelp
    esac
fi
