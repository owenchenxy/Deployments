#!/bin/bash
ENV_PREFIX/Users/chenxi/BIM360/env_shell/dm/
FOLDER=~/tmp
QA_FRONT_PROFILE=dm-qa-front
DEV_FRONT_PROFILE=dm-dev-front
STG_FRONT_PROFILE=dm-stg-front
EU_STG_FRONT_PROFILE=dm-stg-eu-front
PROD_FRONT_PROFILE=dm-prod-front
EU_PROD_FRONT_PROFILE=dm-prod-eu-front

read -p "Which Environment to be Deployed(stg/prod/eu-stg/eu-prod)?"
ENV=$REPLY
ENV_FILE=ENV_PREFIX${ENV}.sh
[[ ! -f $ENV_FILE ]] && echo "Failed.Env shell script ${ENV_FILE} doesn't exist. Please check your input." && exit 1

source $ENV_FILE
[[ -d $FOLDER ]] && rm -rf $FOLDER
read -p "Please Specify Target Assets Revision:  "
targetAssetsRevision=$REPLY
devAssetsRevision=$(curl https://docs.b360-dev.autodesk.com/health | jq .build.assets_revision)
qaAssetsRevision=$(curl https://docs.b360-qa.autodesk.com/health | jq .build.assets_revision)
stgAssetsRevision=$(curl https://docs.b360-staging.autodesk.com/health | jq .build.assets_revision)
euStgAssetsRevision=$(curl https://docs.b360-staging.eu.autodesk.com/health | jq .build.assets_revision)

#Download the Assets package of target version
#For Staging US/EU env, download from qa or dev
#For Production US, download from staging US
#For Production EU, download from staging EU
downloadAssets(){
    case $1 in 
        stg|eu-stg)
            if [[ qaAssetsRevision == targetAssetsRevision ]]
            then
                aws s3 cp s3://bim360-dm-qa-front/assets/assets-$targetAssetsRevision.tar.gz ~/tmp/  --profile=$QA_FRONT_PROFILE
                [[ $? != 0 ]] && echo "Download Assets from QA Failed" && exit 1 || echo "assets-$targetAssetsRevision.tar.gz downloaded from QA s3" 
            elif [[ devAssetsRevision == targetAssetsRevision ]]
            then
                aws s3 cp s3://bim360-dm-dev-front/assets/assets-$targetAssetsRevision.tar.gz ~/tmp/  --profile=$DEV_FRONT_PROFILE
                [[ $? != 0 ]] && echo "Download Assets from DEV Failed" && exit 1 || echo "assets-$targetAssetsRevision.tar.gz downloaded from DEV s3"
            else
                echo "Target Assets Revision is not found on DEV/QA" && exit 1
            fi
        ;;
        prod)
            if [[ stgAssetsRevision == targetAssetsRevision ]]
            then
                aws s3 cp s3://bim360-dm-stg-front/assets/assets-$targetAssetsRevision.tar.gz ~/tmp/  --profile=$STG_FRONT_PROFILE
                [[ $? != 0 ]] && "Download Assets from Staging Failed" && exit 1 || echo "assets-$targetAssetsRevision.tar.gz downloaded from Staging s3"
            fi
        ;;
        eu-prod)
            if [[ euStgAssetsRevision == targetAssetsRevision ]]
            then
                aws s3 cp s3://bim360-dm-stg-eu-front/assets/assets-$targetAssetsRevision.tar.gz ~/tmp/  --profile=$EU_STG_FRONT_PROFILE
                [[ $? != 0 ]] && "Download Assets from EU Staging Failed" && exit 1 || echo "assets-$targetAssetsRevision.tar.gz downloaded from EU Staging s3"
            fi
        ;;
    esac

} 
extractAssets(){
    cd $FOLDER && tar -xvzf $FOLDER/assets-$targetAssetsRevision.tar.gz
}
syncAssetsToS3(){
    case $1 in
        stg)
            S3_BUCKET="s3://bim360-dm-stg-front/assets"
            PROFILE=$STG_FRONT_PROFILE    
        ;;        
        eu-stg)
            S3_BUCKET="s3://bim360-dm-stg-eu-front/assets"
            PROFILE=$EU_STG_FRONT_PROFILE
        ;;
        prod)
            S3_BUCKET="s3://bim360-dm-prod-front/assets"
            PROFILE=$PROD_FRONT_PROFILE
        ;;
        eu-prod)
            S3_BUCKET="s3://bim360-dm-prod-eu-front/assets"
            PROFILE=$EU_PROD_FRONT_PROFILE
        ;;
    esac
    aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE
    
    
}
downloadAssets $ENV

