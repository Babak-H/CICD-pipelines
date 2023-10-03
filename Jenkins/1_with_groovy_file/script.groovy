def testApp {
    echo 'running tests...'
}

def deployApp {
    echo "deploying the app to ${params.TARGET}"
    echo "deploying with ${SERVER_CREDENTIALS}"
    // we can also import enviromental variables in one stage, if they are only needed there
    withCredentials([
        usernamePassword(credentialsId: 'test-server-creds', usernameVariable: 'USER', passwordVarialbe: 'PWD')
    ]) {
        sh "${USER} ${PWD} >> test-pass.txt"
    }
}

return this