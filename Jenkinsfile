#!/usr/bin/env groovy

# ECR name
def ECSREPO = 'ECS-REPO'

// Ensure there aren't any numbers for the repo due to CF limitations
def GITHUBREPO = 'reponame'
def REDISNAME = GITHUBREPO.replaceAll(/-/,'')

def AWSREGION = 'ap-southeast-2'
def ECR = 'XXXXXXXXXXXX.dkr.ecr.ap-southeast-2.amazonaws.com/'
def TEMPLATEURL = ''
def IDKEY = '/root/.ssh/id_rsa'
def DNSENV = 'xxxxx.xxx.com'
def ELBZONEID = ''
def S3BUCKET = 's3://s3bucket123.com'
def HEALTHCHECKPATH = '/healthcheck'
def DEPLOYENV = 'Development'

// Run commands to pass to containers
def RUNCMD = 'start'

def BUILDID = env.BUILD_ID.toInteger()
def BRANCH = env.BRANCH_NAME.toLowerCase();
def CFGITHUBREPO = GITHUBREPO.replaceAll(/\./,'-')
def DNSNAME = CFGITHUBREPO + '-' + BRANCH.replaceAll(/.*\//,'').replaceAll(/[^A-Za-z0-9]/,'-').replaceAll(/-$/,'') + '-' + RUNCMD + '.dev'

// Stackname without the build ID
def BASESTACKNAME =  'prefix-' + DEPLOYENV.toLowerCase() + '-' + CFGITHUBREPO + '-' + BRANCH.replaceAll(/.*\//,'').replaceAll(/[^A-Za-z0-9]/,'-').replaceAll(/-$/,'') + '-' + RUNCMD
def DOCKERTAG = GITHUBREPO.replaceAll(/\./,'-') + '-' + BRANCH.replaceAll(/[^A-Za-z0-9]/,'-')
def DOCKERIMAGE = ECR + ECSREPO + ':' + DOCKERTAG
def STACKNAME = BASESTACKNAME + '-' + BUILDID
def TASKDEFINITION = ECSREPO + '-TD'

node("agent") {

  try {

    stage('Checkout Repo') {
      checkout scm
    }

    stage('ECR Login') {
      sh("\$(aws ecr get-login --no-include-email --region ${AWSREGION}) &> /dev/null")
    }

    stage('Build Container') {
      sh("set +x; docker build --rm "
          + "--build-arg \"RSA_KEY=\$(cat ${IDKEY})\" "
          + "--build-arg \"NODE_ENV=development\" "
          + "--build-arg \"API_ENV=development\" "
          + "--build-arg \"SSM_SECRET=\$(aws ssm get-parameter --name SSM-Secret --with-decryption --region ap-southeast-2 --query 'Parameter.Value' --output text)\" "
          + "-t ${DOCKERIMAGE} .")
    }

    stage('Push to ECR') {
      sh("docker push ${DOCKERIMAGE}")
    }

    stage('Trigger Test Job') {
      def COMMITSHA = sh(returnStdout: true, script: "git rev-parse HEAD").trim()
        build job: '/QA/test-coverage', wait: false, parameters: [[$class: 'StringParameterValue', name: "IMAGE", value: "${DOCKERIMAGE}" ], [$class: 'StringParameterValue', name: "SHA", value: "${COMMITSHA}" ], [$class: 'StringParameterValue', name: "REPO", value: "${GITHUBREPO}" ]]
    }

    stage('Deploy Stack') {
      sh("aws cloudformation create-stack --stack-name ${STACKNAME} --template-url ${TEMPLATEURL} --capabilities CAPABILITY_IAM --parameters ParameterKey=DockerImage,ParameterValue=${DOCKERIMAGE} ParameterKey=Container,ParameterValue=${STACKNAME} ParameterKey=HealthCheckURL,ParameterValue=${HEALTHCHECKPATH}  ParameterKey=Environment,ParameterValue=${DEPLOYENV} ParameterKey=ContainerCommandStart,ParameterValue=${RUNCMD} ParameterKey=RedisName,ParameterValue=${REDISNAME} --region ${AWSREGION}")

        sh("aws cloudformation wait stack-create-complete --stack-name ${STACKNAME} --region ${AWSREGION}")
    }

    stage('Update DNSes') {
      def ELBDNS = sh(returnStdout: true, script: "aws cloudformation describe-stacks --region ${AWSREGION} --stack-name ${STACKNAME} --output text --query 'Stacks[*].Outputs[?OutputKey==`ECSALB`].OutputValue'").trim()
        sh("cli53 rrcreate ${DNSENV} '${DNSNAME} AWS ALIAS A ${ELBDNS} ${ELBZONEID} false' --replace")
    }

    stage('Delete Old Stacks') {
      sh("""
          for i in \\
          \$(aws cloudformation list-stacks --query StackSummaries[*].StackName --no-paginate  --output text --region ${AWSREGION} --stack-status-filter \"CREATE_COMPLETE\" \"UPDATE_COMPLETE\" \"ROLLBACK_COMPLETE\" | xargs -n 1 | grep -E \"${BASESTACKNAME}-[0-9]+\"); do
          if test \"\$(echo \"\${i}\" | sed -E \"s/${BASESTACKNAME}-//g\")\" -lt ${BUILDID} ; then
          printf \"Deleting stack %s\\n\", \"\${i}\"; aws cloudformation delete-stack --stack-name \"\${i}\" --region \"${AWSREGION}\";
          fi;
          done;
          """)
    }
  }

  catch (e) {
    // If there was an exception thrown, the build fails
    currentBuild.result = "FAILED"
      throw e
  } finally {
    // Success or failure, always send notifications
    notifyBuild(currentBuild.result)
  }

  stage('Trigger Update Dashboard Job') {
    build job: '/Update Dashboard'
  }
}

def notifyBuild(String buildStatus = 'STARTED') {
  // build status of null means successful
  buildStatus =  buildStatus ?: 'SUCCESSFUL'

    def DASHURL = ''
    def colorName = 'RED'
    def colorCode = 'danger'

    // Grab the committer
    def BUILDID = env.BUILD_ID.toInteger()
    def GITCOMMITER = sh(returnStdout: true, script: "git show -s --pretty=%an").trim()
    def GITCOMMIT = sh(returnStdout: true, script: "git log --format=%B -n 1 \$(git rev-parse HEAD)").trim()

    def subject = "${buildStatus}: ${env.JOB_NAME} [#${env.BUILD_NUMBER}]"
    def summary = "<${env.BUILD_URL}|${subject}> \n ${GITCOMMITER}: ${GITCOMMIT}\n<${DASHURL}|Dashboard>"

    // Override default values based on build status
    if (buildStatus == 'STARTED') {
      color = 'YELLOW'
        colorCode = 'warning'
    } else if (buildStatus == 'SUCCESSFUL') {
      color = 'GREEN'
        colorCode = 'good'
    } else {
      color = 'RED'
        colorCode = 'danger'
    }

  // Send slack notification
  slackSend channel: '#CI', color: colorCode, message: summary, teamDomain: 'teamdomain'
}
