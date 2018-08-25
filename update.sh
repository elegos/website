#!/usr/bin/env bash
set -e

echo "Do you really want to publish (y/n)? "

read i_am_sure

if [ "$i_am_sure" != "y" ]; then
  echo -e "\nok, bye!"
  exit 0
fi

echo "Cleaning the public directory..."
rm -rf `pwd`/public/*

echo "Generating the static files..."
hugo

echo "Committing the new content."
now=`date "+%Y-%m-%d %H:%M:%S"`
cd public
git add .
git commit -m "Site updated: $now"
git push origin master
