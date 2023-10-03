#!/usr/bin/env groovy

def call(String imageName) {
    echo "building the image..."
    withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', usernameVariable: 'USER', passwordVarialbe: 'PASS')]) {
        sh "docker build -t $imageName ."
        sh "echo $PASS | docker login -u $USER --password-stdin "
        sh "docker push $imageName"
}
