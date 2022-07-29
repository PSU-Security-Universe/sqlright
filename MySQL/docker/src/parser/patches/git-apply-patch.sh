#!/bin/bash

pushd ../mysql-server
  git checkout mysql-8.0.27
  git apply < ../patches/history.patch
popd
