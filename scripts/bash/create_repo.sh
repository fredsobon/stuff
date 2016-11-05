cat create_repo_dated.sh 
#! /bin/bash

CMD=$(which pulp-admin)
LOGIN="lapin"
PASSWD="nain"
CMD_OPTS="rpm repo list"

function usage() {
    echo "create_repo_dated.sh <-i> <-a> [-d YYYYMMDD]"
    echo "-i: interactive mode"
    echo "-a: in automatic mode, create a dated repo for all repositories"
    echo "-d: optional dated, for example 20151225"
    echo "-h: this message"
    exit 0
}

function check_repo() {
    repo=$1
    exists=`$CMD -u $LOGIN -p $PASSWD $CMD_OPTS --repo-id $1 | grep Id`
    if [ -z "$exists" ]; then
        echo "Repository $1 does not exists"
        exit 1
    fi
}

function list_repos() {
    list=$(eval "$CMD -u $LOGIN -p $PASSWD $CMD_OPTS_LIST | grep Id | cut -d: -f2 | sed -e s/"-mirror"// -e s/"-prod"// -e s/"-testing"//" | sort | uniq)
    echo "- Choose a repository:"
    idx=0
    for i in $list; do
        echo "    $idx - $i"
        repos[$idx]=$i
        idx=`expr $idx + 1`
    done
}

while [ $# -gt 0 ]; do
    #echo "option = $1"
    case "$1" in
        "-h")
            usage
            shift
            ;;
        "-a")
            CREATEALL="yes"
            ;;
        "-i")
            INTERACTIVE="yes"
            ;;
        "-d")
            DATED=$2
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

CMD=$(which pulp-admin)
LOGIN="lapin"
PASSWD="nain"
CMD_OPTS_LIST="rpm repo list"
CMD_OPTS_CREATE="rpm repo create --serve-http false --repo-id"
NOW=$(date +%Y%m%d)
DATED=${DATED:-$NOW}

if [ -z "$CREATEALL" ]; then
    if [ -z "$INTERACTIVE" ]; then
        echo "Please specify an option"
        usage
    else
        list_repos
        echo
        echo "Repo number:"
        read resp

        if [ -z "${repos[$resp]}" ]; then
            echo "The repository you choosed does not exist"
            exit 1
        fi

        echo "You choose ${repos[$resp]}"

        echo "We will create repository named ${repos[$resp]}-$DATED"
        confirm=""
        echo "Do you confirm? (y/n)"
        while [ -z "$confirm" ]; do
            read confirm
        done
        if [[ "$confirm" == "Y" || "$confirm" == "y" ]]; then
            $CMD -u $LOGIN -p $PASSWD $CMD_OPTS_CREATE ${repos[$resp]}-$DATED
        else
            echo "Cancelation - Exit!"
            exit 0
        fi

        confirm=""
        echo "Do you want to copy RPMs from the origin repository (${repos[$resp]})? (y/n)"
        while [ -z "$confirm" ]; do
            read confirm
        done
        if [[ "$confirm" == "Y" || "$confirm" == "y" ]]; then
            echo "We are going to copy every RPMs from ${repos[$resp]} to ${repos[$resp]}-$DATED"
            $CMD -u $LOGIN -p $PASSWD rpm repo copy rpm --recursive --from-repo-id "${repos[$resp]}-mirror" --to-repo-id ${repos[$resp]}-$DATED
        else
            echo "Cancelation - Exit!"
            exit 0
        fi
    fi
else
    echo "Creation dated repo for all Repos"
    list_repos=$(eval "$CMD -u $LOGIN -p $PASSWD $CMD_OPTS_LIST | grep Id | cut -d: -f2 | grep mirror | sort | uniq")
    for i in $list_repos; do
        repo_name=`echo $i | sed -e s/"-mirror"//`
        exists=`$CMD -u $LOGIN -p $PASSWD rpm repo list | grep ${repo_name}-$DATED`
        if [ -z "$exists" ]; then
            echo "We will create repo ${repo_name}-$DATED"
            $CMD -u $LOGIN -p $PASSWD rpm repo create --remove-missing true --serve-http false --repo-id ${repo_name}-$DATED
        else
            echo "The repo ${repo_name}-$DATED already exists"
        fi
    done
fi

