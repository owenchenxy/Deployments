#!/bin/bash
FOLDER=~/tmp/assets
QA_FRONT_PROFILE=dm-qa-front
DEV_FRONT_PROFILE=dm-dev-front
STG_FRONT_PROFILE=dm-stg-front
EU_STG_FRONT_PROFILE=dm-stg-eu-front
PROD_FRONT_PROFILE=dm-prod-front
EU_PROD_FRONT_PROFILE=dm-prod-eu-front

echo "\\033[0;34mINPUT>>>Which Environment to be Deployed(stg/prod/eu-stg/eu-prod)?\c" && read
ENV=$REPLY
echo "\\033[0;34mINPUT>>>Please Specify Target Assets Revision:\c" && read
TARGET_ASSETS_REVISION=$REPLY

[[ -d $FOLDER ]] || mkdir -p $FOLDER
[[ -f $FOLDER/assets-$TARGET_ASSETS_REVISION.tar.gz ]] && SKIP_DOWNLOAD_ASSETS=1
echo $SKIP_DOWNLOAD_ASSETS

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
                echo "\\033[0;33mCMD>>>aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$QA_FRONT_PROFILE"
                aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/ --profile=$QA_FRONT_PROFILE
                [[ $? != 0 ]] && echo "\\033[0;31mERROR>>>Download Assets from QA Failed" && exit 1 || echo "\\033[0;32mSUCCESS>>>assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from QA s3" 
            elif [[ $DEV_ASSETS_REVISION == $TARGET_ASSETS_REVISION ]]
            then
                echo "\\033[0;33mCMD>>>aws s3 cp s3://bim360-dm-dev-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$DEV_FRONT_PROFILE"
                aws s3 cp s3://bim360-dm-dev-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$DEV_FRONT_PROFILE
                [[ $? != 0 ]] && echo "\\033[0;31mERROR>>>Download Assets from DEV Failed" && exit 1 || echo "\\033[0;32mSUCCESS>>>assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from DEV s3"
            else
                echo "\\033[0;33mCMD>>>aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$QA_FRONT_PROFILE"
                echo "\\033[0;33mWARNING>>>assets-$TARGET_ASSETS_REVISION is not Deployed to DEV or QA. Trying to Find in QA front s3..."
                aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/ --profile=$QA_FRONT_PROFILE
                [[ $? != 0 ]] && echo "\\033[0;31mERROR>>>Download Assets from QA Failed" && exit 1 || echo "\\033[0;32mSUCCESS>>>assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from QA s3"
            fi
        ;;
        prod)
            if [[ $STG_ASSETS_REVISION == \"$TARGET_ASSETS_REVISION\" ]]
            then
                echo "\\033[0;33mCMD>>>aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$QA_FRONT_PROFILE"
                aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$QA_FRONT_PROFILE
                [[ $? != 0 ]] && echo "\\033[0;31mERROR>>>Download Assets from QA Failed" && exit 1 || echo "\\033[0;32mSUCCESS>>>assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from QA s3"
            else
                echo "\\033[0;31mERROR>>>This Assets Revision has not been deployed to STG" && exit 1
            fi
        ;;
        eu-prod)
            if [[ $EU_STG_ASSETS_REVISION == \"$TARGET_ASSETS_REVISION\" ]]
            then
                echo "\\033[0;33mCMD>>>aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$QA_FRONT_PROFILE"
                aws s3 cp s3://bim360-dm-qa-front/assets/assets-$TARGET_ASSETS_REVISION.tar.gz $FOLDER/  --profile=$QA_FRONT_PROFILE
                [[ $? != 0 ]] && echo "\\033[0;31mERROR>>>Download Assets from QA Failed" && exit 1 || echo "\\033[0;32mSUCCESS>>>assets-$TARGET_ASSETS_REVISION.tar.gz downloaded from QA s3"
            else
                echo "\\033[0;31mERROR>>>This Assets Revision has not been deployed to EU STG" && exit 1
            fi
        ;;
    esac

} 
#extract the Assets package to dist/ folder
extractAssets(){
    echo "\\033[0;33mCMD>>>tar -xvzf $FOLDER/assets-$TARGET_ASSETS_REVISION.tar.gz"
    cd $FOLDER && tar -xvzf $FOLDER/assets-$TARGET_ASSETS_REVISION.tar.gz
    [[ $? != 0 ]] && echo "Extract Assets Failed" && exit 1 || echo "\\033[0;32mSUCCESS>>>Successfully extracted assets files to $FOLDER/dist "
    
}
#sync upload the files in dist/ folder to s3
syncAssetsToS3(){
    case $1 in
        stg)
            S3_BUCKET="s3://bim360-dm-stg-front/assets"
            PROFILE=$STG_FRONT_PROFILE    
        ;;        
        eu-stg)
            echo "env is eu-stg"
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
    echo "\\033[0;33mCMD>>>aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE"
    aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE
    if [[ $? != 0 ]]
    then
        echo "\\033[0;31mERROR>>>Failed Uploading Assets Files to S3 . Re-trying..."
        echo "\\033[0;33mCMD>>>aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE"
        aws s3 sync $FOLDER/dist $S3_BUCKET --only-show-errors --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $PROFILE
        [[ $? != 0 ]] && echo "\\033[0;31mERROR>>>Failed Uploading Assets Files to S3. Exit..." && exit 1 || echo "\\033[0;33mWARNING>>>Warning:Successfully Uploading Assets Files to S3 but on 2nd Try"
    else
        echo "\\033[0;32mSUCCESS>>>Successfully Uploading Assets Files to S3"
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
    [[ $ONLINE_ASSETS_REVISION == '' ]] && echo "\\033[0;31mERROR>>>Online Assets Revision mismatch with Target Revision. Assets deployment unsuccessful." && exit 1
    echo "\\033[0;32mSUCCESS>>>Assets Deployment Succeed!"
}
[[ $SKIP_DOWNLOAD_ASSETS == 1 ]] && echo "Assets Files already fully retrived. Skip downloading" || downloadAssets $ENV 
extractAssets
syncAssetsToS3 $ENV
verifyAssets $ENV