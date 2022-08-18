#!/bin/sh

rawdata=$1
out=$2
case=$3

# make output directoreis for subject/session
if [ ! -d $out/$case ]; then
  mkdir $out/$case -p

  # convert and bias correct INV2 and UNI
  for type in INV2 UNI cest none; do
    /project/bbl_projects/apps/melliott/scripts/dicom2nifti.sh -u -F \
      $out/$case/$case-$type.nii \
      $rawdata/$case/S*$type*/*dcm
  done

  cp $rawdata/$case/* $out/$case/ -r

fi
