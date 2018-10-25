node {
    if (params.ENV_KEY != ""){
        stage('update aws configs'){
            sh '''
            echo "current_user:$(whoami)"
            cp -R /Users/chenxi/.aws /Users/Shared/Jenkins
            '''
        }
        stage('delete local sec file if existed'){
            sh '''
              if [ -e ~/dm_secrets ]
              then 
              	rm ~/dm_secrets
              fi
            '''
        }
        stage('Download secrets file from s3'){
            sh '''
            aws s3 cp s3://bim360-dm-dev-s3/dm_secrets ~/ --profile dev
            '''
        }
        stage('Edit downloaded ENV file'){
            sh '''
            sed -n "/^${ENV_KEY}[[:blank:]]*/p" ~/dm_secrets
            sed -i '' "/^${ENV_KEY}[[:blank:]]*/d" ~/dm_secrets
            if [ ${ENV_VALUE} != "" ]
            then
            echo "${ENV_KEY}=${ENV_VALUE}" >> ~/dm_secrets
            fi
            '''
        }
        stage('Upload edited sec file to s3'){
            sh '''
            aws s3 cp ~/dm_secrets s3://bim360-dm-dev-s3/dm_secrets --profile dev
            '''
        }
        stage('clean up local sec file'){
            sh '''
            rm ~/dm_secrets
            '''
        }
        stage('Show the s3 contents after uploading'){
            sh '''
            aws s3 ls s3://bim360-dm-dev-s3/ --profile dev
            '''
        }
    }
    
}