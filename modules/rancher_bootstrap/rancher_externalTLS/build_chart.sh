#!/bin/bash

set -x

RANCHER_VERSION="$1"
if [ -z "$RANCHER_VERSION" ]; then echo "you must send the Rancher version"; exit 1; fi
if [ "${RANCHER_VERSION:0:1}" != "v" ]; then RANCHER_VERSION="v$RANCHER_VERSION"; fi

git clone https://github.com/rancher/rancher.git
cd rancher || exit 1
git checkout "$RANCHER_VERSION"
cd .. || exit 1
mv rancher/chart ./chart
mv rancher/build.yaml ./config.yaml
rm -rf rancher
mv chart rancher

VERSION="$RANCHER_VERSION"
CHART_VERSION="$(echo "$RANCHER_VERSION" | tr -d 'v')"
CONFIG="config.yaml"

CATTLE_DEFAULT_SHELL_VERSION=$(yq -r -e '.defaultShellVersion' "$CONFIG")

sed -i -e "s/%VERSION%/$CHART_VERSION/g" rancher/Chart.yaml
sed -i -e "s/%APP_VERSION%/$VERSION/g" rancher/Chart.yaml

post_delete_base="$CATTLE_DEFAULT_SHELL_VERSION"
post_delete_image_name=$(echo "$post_delete_base" | tr -d '"' | cut -d ":" -f 1) || true;
post_delete_image_tag=$(echo "$post_delete_base" | tr -d '"' | cut -d ":" -f 2) || true;
if [[ ! $post_delete_image_name =~ ^rancher\/.+ ]]; then
  echo "The image name [$post_delete_image_name] is invalid. Its prefix should be rancher/"
  exit 1
fi
if [[ ! $post_delete_image_tag =~ ^v.+ ]]; then
  echo "The image tag [$post_delete_image_tag] is invalid. It should start with the letter v"
  exit 1
fi
# image name has slashes in it and image tag has at symbols in it
sed -i -e "s@%POST_DELETE_IMAGE_NAME%@$post_delete_image_name@g" rancher/values.yaml
sed -i -e "s/%POST_DELETE_IMAGE_TAG%/$post_delete_image_tag/g" rancher/values.yaml

helm lint "$(pwd)/rancher"

helm package "$(pwd)/rancher"
