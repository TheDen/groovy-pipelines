# groovy-pipelines


## Jenkinsfile tips

* Use the shebang: `#!/usr/bin/env groovy`.
* Use comments— `//` and `/* */` are supported.
* Use [stages](https://jenkins.io/doc/book/pipeline/syntax/#stage) to logically separate tasks.
* Use `try`, `catch`, `finally` within Jenkinsfiles.
* Don't use inline scripts for nontrivial projects.
* Make use of Jenkins' [environment variables](https://wiki.jenkins.io/display/JENKINS/Building+a+software+project#Buildingasoftwareproject-JenkinsSetEnvironmentVariables)
* Use `git` to grab commit information instead of Jenkins' built-in git environment variables.
* Avoid depending on plugins. They can break and/or be out of date. It's almost always easier and faster to update your code than wait for a plugin patch.


## Groovy tips and tricks

### Useful Groovy Methods

* `toLowerCase()` — Converts all of the characters in a String to lower case.
* `toUpperCase()` — Converts all of the characters in a String to upper case.
* `toString()` — The method is used to get a String object representing the value of the Number Object.
* `toInteger()` — The method is used to get a Number Object object representing the value of the String object.
* `concat() ` — Concatenates the specified String to the end of this String. This can also be done by the simple `+` operator.
* `matches()` — It outputs whether a String matches the given regular expression.
* `subString()` — Returns a new String that is a substring of this String.

### Escaping

Use the [snippet generator](https://jenkins.io/doc/book/pipeline/getting-started/#snippet-generator)

* For bash variables, escape the dollar sign, e.g., `sh("echo \$var")`. Note that `sh("echo ${VAR}")` would refer to the groovy variable `var`.
* Double quotes need to be escaped, e.g., `sh("echo \"hello world\"")`.


### Using the stdout as a variable:
```def zip = sh(returnStdout: true, script: "echo \"zipfile-\$(date '+%Y-%m-%d.%H.%M.%S-build')${env.BUILD_ID}.zip\"").trim()```

Note that `.trim()` strips out the newline.

### Using the build number as an integer:
`def BUILDID = env.BUILD_ID.toInteger()`

### Find and replace

```
def var = 'remove-my-dashes'
def dashless = var.replaceAll(/-/,'')
```

### Multiline scripts

```
sh("""
   for i in
   \$(seq 1 10); do
   echo \"\$i\"
   done;
   """)

```

### Triggering other builds

To trigger a build, the path after `/job/` needs to be passed.
For example, with the URL for the job
`https://jenkinserver.com/job/folder1/folder2/myjob`

```
stage('Trigger Another Job') {
  build job: '/folder1/folder2/myjob'
}
```
will trigger a build. An example on how to pass variables and running a job without waiting (so in parallel).

```
build job: '/QA/run-tests', wait: false, parameters: [[$class: 'StringParameterValue', name: "IMAGE", value: "${IMAGE}" ], [$class: 'StringParameterValue', name: "SHA", value: "${COMMITSHA}" ], [$class: 'StringParameterValue', name: "REPO", value: "reponame"]]
```

### Loading credentials
Inject a secret as a variable
```withCredentials([[ $class: 'StringBinding', credentialsId: 'XXXXX', variable: 'PASSPHRASE']]) { sh("cli-tool -p ${PASSPHRASE}") }```


Loading multiple secrets

```
withCredentials([string(credentialsId: 'KeyAlias', variable: 'KeyAlias'), string(credentialsId: 'KeyPassword', variable: 'KeyPassword'), string(credentialsId: 'StorePassword', variable: 'StorePassword'), file(credentialsId: 'keystore', variable: 'keystore')])
```

### Viewing forgotten secrets

Jenin's credentials binding does not let you see secrets once they're set. If for some reason you need to see the secret, you can simple redirect the value to a file and then access the file on the node. For example:

```withCredentials([[ $class: 'lostpw', credentialsId: 'lostpw', variable: 'PASSPHRASE']]) { sh("echo \"${lostpw}\" > /tmp/pw ") }```


### Setting custom environments

For example, to set an Android env:
```
withEnv(['ANDROID_HOME=/usr/local/android-sdk-linux/', "PATH=$PATH:/usr/local/android-sdk-linux/tools:/usr/local/android-sdk-linux/platform-tools:/usr/local/android-sdk-linux/tools/bin"]) {
sh("./gradlew")
}
```
