#!/bin/bash
ENV_PREFIX=/Users/chenxi/BIM360/env_shell/dm/
FOLDER=~/tmp/assets
QA_FRONT_PROFILE=dm-qa-front
DEV_FRONT_PROFILE=dm-dev-front
STG_FRONT_PROFILE=dm-stg-front
EU_STG_FRONT_PROFILE=dm-stg-eu-front
PROD_FRONT_PROFILE=dm-prod-front
EU_PROD_FRONT_PROFILE=dm-prod-eu-front

read -p "Which Environment to be Deployed(stg/prod/eu-stg/eu-prod)?"
ENV=$REPLY
ENV_FILE=${ENV_PREFIX}${ENV}.sh
[[ ! -f $ENV_FILE ]] && echo "Failed.Env shell script ${ENV_FILE} doesn't exist. Please check your input." && exit 1
read -p "Please Specify Target Assets Revision:  "
TARGET_ASSETS_REVISION=$REPLY

source $ENV_FILE
[[ -d $FOLDER ]] && rm -rf $FOLDER  || mkdir -p $FOLDER

DEV_ASSETS_REVISION=$(curl -s https://docs.b360-dev.autodesk.com/health | jq .build.assets_revision)
QA_ASSETS_REVISION=$(curl -s https://docs.b360-qa.autodesk.com/health | jq .build.assets_revision)
STG_ASSETS_REVISION=$(curl -s https://docs.b360-staging.autodesk.com/health | jq .build.assets_revision)
EU_STG_ASSETS_REVISION=$(curl -s https://docs.b360-staging.eu.autodesk.com/health | jq .build.assets_revision)

#Download the Assets package of target version
#For Staging US/EU env, download from qa or dev
#For Production US, download from staging US
#For Production EU, download from staging EU
downloadAssets(){
    case $1 in 
        stg|eu-stg)
            if [[ $QA_ASSETS_REVISION == \"$TARGET_ASSETS_REVISION\" ]]
            then
                echo "aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$QA_FRONT_PROFILE"
                #aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/ --profile=$QA_FRONT_PROFILE
                [[ $? != 0 ]] && echo "Download Assets from QA Failed" && exit 1 || echo "assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from QA s3" 
            elif [[ $DEV_ASSETS_REVISION == $TARGET_ASSETS_REVISION ]]
            then
                echo "aws s3 cp s3://bim360-dm-dev-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$DEV_FRONT_PROFILE"
                #aws s3 cp s3://bim360-dm-dev-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$DEV_FRONT_PROFILE
                [[ $? != 0 ]] && echo "Download Assets from DEV Failed" && exit 1 || echo "assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from DEV s3"
            else
                echo "Target Assets Revision is not found on DEV/QA" && exit 1
            fi
        ;;
        prod)
            if [[ $STG_ASSETS_REVISION == $TARGET_ASSETS_REVISION ]]
            then
                echo "aws s3 cp s3://bim360-dm-stg-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$STG_FRONT_PROFILE"
                #aws s3 cp s3://bim360-dm-stg-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$STG_FRONT_PROFILE
                [[ $? != 0 ]] && "Download Assets from Staging Failed" && exit 1 || echo "assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from Staging s3"
            fi
        ;;
        eu-prod)
            if [[ $EU_STG_ASSETS_REVISION == $TARGET_ASSETS_REVISION ]]
            then
                echo "aws s3 cp s3://bim360-dm-stg-eu-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$EU_STG_FRONT_PROFILE"
                #aws s3 cp s3://bim360-dm-stg-eu-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$EU_STG_FRONT_PROFILE
                [[ $? != 0 ]] && "Download Assets from EU Staging Failed" && exit 1 || echo "assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from EU Staging s3"
            fi
        ;;
    esac

} 
#extract the Assets package to dist/ folder
extractAssets(){
    cd $FOLDER #&& tar -xvzf $FOLDER/assets-$TARGET_ASSETS_REVISION.tar.gz
    echo "tar -xvzf $FOLDER/assets-$TARGET_ASSETS_REVISION.tar.gz"
}
#sync upload the files in dist/ folder to s3
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
    echo "aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE"
    #aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE
    if [[ $? != 0 ]]
    then
        echo "Failed Uploading Assets Files to S3 . Re-trying..."
        echo "aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE"
        #aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE
        [[ $? != 0 ]] && echo "Failed Uploading Assets Files to S3. Exit..." && exit 1
    fi
}
verifyAssets(){
    case $1 in
        stg)
            FRONT_FILE_LOCATION="https://docs.b360-staging.autodesk.com/assets/webpack-manifest-$TARGET_ASSETS_REVISION.json"
        ;;
        eu-stg)
            FRONT_FILE_LOCATION="https://docs.b360-staging.eu.autodesk.com/assets/webpack-manifest-$TARGET_ASSETS_REVISION.json"
        ;;
        prod)
            FRONT_FILE_LOCATION="https://docs.b360.autodesk.com/assets/webpack-manifest-$TARGET_ASSETS_REVISION.json"
        ;;
        eu-prod)
            FRONT_FILE_LOCATION="https://docs.b360.eu.autodesk.com/assets/webpack-manifest-$TARGET_ASSETS_REVISION.json"
        ;;
    esac
    ONLINE_ASSETS_REVISION=$(curl -s $FRONT_FILE_LOCATION | grep $TARGET_ASSETS_REVISION)
    [[ $ONLINE_ASSETS_REVISION == '' ]] && echo "Online Assets Revision mismatch with Target Revision. Assets deployment unsuccessful." && exit 1
    echo "Assets Deployment Succeed!"

}


downloadAssets $ENV
extractAssets
syncAssetsToS3 $ENV
verifyAssets $ENV
