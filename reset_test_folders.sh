#!/bin/bash

root_dir=$(pwd)
echo -e "Repopulating Test_Folder with Test_Folder.BKP contents."
echo -e "Test_Folder previous:"
ls --color -la Test_Folder
rm -r ./Test_Folder/
rm -r ./Temp/*
cp -r ./Test_Folder.BKP Test_Folder
echo -e "Done"

echo -e "\nTest_Folder contents:"
ls --color -la Test_Folder
