#!/usr/bin/env bash
set -e # Any subsequent(*) commands which fail will cause the shell script to exit immediately

VERSION=$1
ARTIFACT=$2

if [[ $ARTIFACT -z ]]
then
    echo "No Artifact Specified"
fi

SBT_2_11="sbt ++2.11.12 -Dquill.macro.log=false"
SBT_2_12="sbt ++2.12.6 -Dquill.macro.log=false"

if [[ $VERSION -eq 211 ]]
then
    SBT_VER=SBT_2_11
elif [[ $VERSION -eq 212 ]]
then
    SBT_VER=SBT_2_11
else
    echo "No Valid SBT Version Entered"
    exit 1
fi

echo $SBT_CMD
if [[ $TRAVIS_PULL_REQUEST == "false" ]]
then
    openssl aes-256-cbc -pass pass:$ENCRYPTION_PASSWORD -in ./build/secring.gpg.enc -out local.secring.gpg -d
    openssl aes-256-cbc -pass pass:$ENCRYPTION_PASSWORD -in ./build/pubring.gpg.enc -out local.pubring.gpg -d
    openssl aes-256-cbc -pass pass:$ENCRYPTION_PASSWORD -in ./build/credentials.sbt.enc -out local.credentials.sbt -d
    openssl aes-256-cbc -pass pass:$ENCRYPTION_PASSWORD -in ./build/deploy_key.pem.enc -out local.deploy_key.pem -d

    ls -ltr
    sleep 3 # Need to wait until credential files fully written or build fails sometimes

    if [[ $TRAVIS_BRANCH == "master" && $(cat version.sbt) != *"SNAPSHOT"* ]]
    then
        eval "$(ssh-agent -s)"
        chmod 600 local.deploy_key.pem
        ssh-add local.deploy_key.pem
        git config --global user.name "Quill CI"
        git config --global user.email "quillci@getquill.io"
        git remote set-url origin git@github.com:getquill/quill.git

        if [[ $ARTIFACT -eq "base" ]]; then    $SBT_VER -Dmodules=base -DskipPush=true 'release with-defaults'; fi
        if [[ $ARTIFACT -eq "db" ]]; then      $SBT_VER -Dmodules=db -DskipPush=true 'release with-defaults'; fi
        if [[ $ARTIFACT -eq "async" ]]; then   $SBT_VER -Dmodules=async -DskipPush=true 'release with-defaults'; fi
        if [[ $ARTIFACT -eq "codegen" ]]; then $SBT_VER -Dmodules=codegen -DskipPush=true 'release with-defaults'; fi
        if [[ $ARTIFACT -eq "bigdata" ]]; then $SBT_VER -Dmodules=bigdata 'release with-defaults default-tag-exists-answer o'; fi

    elif [[ $TRAVIS_BRANCH == "master" ]]
    then
        if [[ $ARTIFACT -eq "base" ]];    $SBT_VER -Dmodules=base publish; fi
        if [[ $ARTIFACT -eq "db" ]];      $SBT_VER -Dmodules=db publish; fi
        if [[ $ARTIFACT -eq "async" ]];   $SBT_VER -Dmodules=async publish; fi
        if [[ $ARTIFACT -eq "codegen" ]]; $SBT_VER -Dmodules=codegen publish; fi
        if [[ $ARTIFACT -eq "bigdata" ]]; $SBT_VER -Dmodules=bigdata publish; fi
    else
        echo "version in ThisBuild := \"$TRAVIS_BRANCH-SNAPSHOT\"" > version.sbt
        if [[ $ARTIFACT -eq "base" ]];    $SBT_VER -Dmodules=base publish; fi
        if [[ $ARTIFACT -eq "db" ]];      $SBT_VER -Dmodules=db publish; fi
        if [[ $ARTIFACT -eq "async" ]];   $SBT_VER -Dmodules=async publish; fi
        if [[ $ARTIFACT -eq "codegen" ]]; $SBT_VER -Dmodules=codegen publish; fi
        if [[ $ARTIFACT -eq "bigdata" ]]; $SBT_VER -Dmodules=bigdata publish; fi
    fi
fi
