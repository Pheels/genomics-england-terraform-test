#!/usr/bin/env bash

LAYER_NAME=$1 # input layer, retrived as arg
ZIP_ARTIFACT=${LAYER_NAME}.zip
LAYER_BUILD_DIR="python"

rm -rf ${LAYER_BUILD_DIR} && mkdir -p ${LAYER_BUILD_DIR}

docker run --rm -v `pwd`:/var/task:z lambci/lambda:build-python3.7 python3.7 -m pip --isolated install -t ${LAYER_BUILD_DIR} -r requirements.txt

zip -r ${ZIP_ARTIFACT} .

rm -rf ${LAYER_BUILD_DIR}
