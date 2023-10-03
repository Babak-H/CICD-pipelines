#!/usr/bin/env groovy

def call() {
    echo "building the package for branch $BRANCH_NAME"
    sh 'mvn package'
}
