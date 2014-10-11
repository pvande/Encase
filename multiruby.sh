#!/bin/sh

if (/usr/bin/which -s rbenv) ; then
  eval "$(rbenv init -)"
else
  printf "ERROR: rbenv not found.n"
fi

versions='1.9.3-p547 2.0.0-p576 2.1.2 2.2.0-preview1'

for version in $versions; do
  (rbenv versions | grep -q $version) || rbenv install $version

  rbenv shell $version

  (gem list 2>/dev/null | grep -q bundler) || gem install bundler

  bundle install &>/dev/null && rbenv rehash

  tput setaf 1; ruby -v ; tput sgr 0
  $@
  echo
done

echo 'Success!'
