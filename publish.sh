#!/usr/bin/env bash

git submodule update --remote public
pushd public
  git checkout master
popd

echo "Cleaning the public directory..."
rm -rf public/*


echo "Generating the static files..."
hugo

echo "Adding CNAME file for custom domain..."
cp CNAME public/CNAME

echo "Committing the new content."
now=`date "+%Y-%m-%d %H:%M:%S"`
pushd public
  git add .
  git commit -m "Site updated: $now"
  git push origin master
popd

git add .
git commit -m "Site updated: $now"
git push origin src
