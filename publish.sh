#!/usr/bin/env bash
set -e

echo "Do you really want to publish (y/n)? "

read i_am_sure

if [ "$i_am_sure" != "y" ]; then
  echo -e "\nok, bye!"
  exit 0
fi

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

echo -e "\nDone! Do you want to update the sources, too?"
read i_am_sure

if [ "$i_am_sure" != "y" ]; then
  echo -e "\nok, bye!"
  exit 0
fi


git add .
git commit -m "Site updated: $now"
git push origin src
