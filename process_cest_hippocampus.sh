#!/bin/bash

## DEFINE PATHS ##
structural=$1
dicoms=$2
cest=$3
atlas=$4
log=$5
sub=$6
ses=$7
case=$8

#######################################################################################################
## IDENTIFY CASES FOR PROCESSING ##

echo "CASE: $case"


#check for structural data
if [ -e $structural/$sub/$ses/MNI_transforms/${sub}_$ses-INV2inMNI-1InverseWarp.nii.gz ]
then
echo "Structural Data exists for $sub $ses"
sleep 1.5
else
echo "Oh No! Structural Data is missing. Cannot process CEST! Run MP2RAGE_Processing_Pipeline.sh first."
sleep 1.5
fi

#check for GluCEST GUI data
if [ -d $dicoms/$case/*WASSR_B0MAP2D ] && \
[ -d $dicoms/$case/*B1MAP2D ] && \
[ -d $dicoms/$case/*B0B1CESTMAP2D ]
then

echo "CEST GUI Data exists for $case"
sleep 1.5
else
echo "Oh No! CEST GUI Data is missing. Cannot process CEST! Analyze this case with CEST_2d_TERRA first."
sleep 1.5
fi

if ! [ -d $cest/$case ] && [ -d $dicoms/$case/*WASSR_B0MAP2D ] && \
[ -d $dicoms/$case/*B1MAP2D ] && [ -d $dicoms/$case/*B0B1CESTMAP2D ]
then

logfile=$sub/$ses/${sub}_$ses-cest.log
{
echo "--------Processing GluCEST data for $sub $ses---------"

#######################################################################################################
## make directories and log files ##
mkdir $cest/$sub/$ses -p
log_files=$cest/$sub/$ses/log_files #path to intermediate files. Remove for final script
mkdir $log_files
mkdir $cest/$sub/$ses/atlases

#######################################################################################################
## CONVERT B0, B1, and B0B1-CORRECTED CEST FROM DCM TO NII ##
for seq in B0MAP B1MAP B0B1CESTMAP
do
  /project/bbl_projects/apps/melliott/scripts/dicom2nifti.sh -u -r Y -F \
    $cest/$sub/$ses/${sub}_$ses-$seq.nii $dicoms/$case/S*${seq}2D/*dcm
done
#######################################################################################################
## THRESHOLD B0 AND B1 MAPS ##

#threshold b0 from -1 to 1 ppm (relative to water resonance)
fslmaths $cest/$sub/$ses/${sub}_$ses-B0MAP.nii \
  -add 10 \
  $cest/$sub/$ses/${sub}_$ses-B0MAP-pos.nii.gz # make B0 map values positive to allow for thresholding with fslmaths
fslmaths $cest/$sub/$ses/${sub}_$ses-B0MAP-pos.nii.gz \
  -thr 9 \
  -uthr 11 \
  $cest/$sub/$ses/${sub}_$ses-B0MAP-thresh.nii.gz #threshold from -1(+10=9) to 1(+10=11)
fslmaths $cest/$sub/$ses/${sub}_$ses-B0MAP-thresh.nii.gz \
  -bin $cest/$sub/$ses/${sub}_$ses-b0.nii.gz #binarize thresholded B0 map

#threshold b1 from 0.3 to 1.3
fslmaths $cest/$sub/$ses/${sub}_$ses-B1MAP.nii \
  -thr 0.3 \
  -uthr 1.3 $cest/$sub/$ses/${sub}_$ses-B1MAP-thresh.nii.gz #threshold from 0.3 to 1.3
fslmaths $cest/$sub/$ses/${sub}_$ses-B1MAP-thresh.nii.gz \
  -bin $cest/$sub/$ses/${sub}_$ses-b1.nii.gz #binarize thresholded B1 map
#######################################################################################################

## APPLY THRESHOLDED B0 MAP, B1 MAP, and TISSUE MAP (CSF removed) TO GLUCEST IMAGES ##

#exclude voxels with B0 offset greater than +- 1 pmm from GluCEST images
fslmaths $cest/$sub/$ses/${sub}_$ses-B0B1CESTMAP.nii \
  -mul $cest/$sub/$ses/${sub}_$ses-b0.nii.gz \
  $cest/$sub/$ses/${sub}_$ses-CEST_b0thresh.nii.gz

#exclude voxels with B1 values outside the range of 0.3 to 1.3 from GluCEST images
fslmaths $cest/$sub/$ses/${sub}_$ses-CEST_b0thresh.nii.gz \
  -mul $cest/$sub/$ses/${sub}_$ses-b1.nii.gz \
  $cest/$sub/$ses/${sub}_$ses-CEST_b0b1thresh.nii.gz

#######################################################################################################
## MASK THE PROCESSED GLUCEST IMAGE ##

fslmaths $cest/$sub/$ses/${sub}_$ses-B1MAP.nii \
  -bin $cest/$sub/$ses/CEST-masktmp.nii.gz
fslmaths $cest/$sub/$ses/CEST-masktmp.nii.gz \
  -ero -kernel sphere 1 \
  $cest/$sub/$ses/CEST-masktmp-er1.nii.gz
fslmaths $cest/$sub/$ses/CEST-masktmp-er1.nii.gz \
  -ero -kernel sphere 1 \
  $cest/$sub/$ses/CEST-masktmp-er2.nii.gz
fslmaths $cest/$sub/$ses/CEST-masktmp-er2.nii.gz \
  -ero -kernel sphere 1 \
  $cest/$sub/$ses/${sub}_$ses-CEST-mask.nii.gz
fslmaths $cest/$sub/$ses/${sub}_$ses-CEST_b0b1thresh.nii.gz \
  -mul $cest/$sub/$ses/${sub}_$ses-CEST-mask.nii.gz \
  $cest/$sub/$ses/${sub}_$ses-GluCEST.nii.gz #final processed GluCEST Image
#######################################################################################################
#clean up and organize, whistle while you work
mv -f $cest/$sub/$ses/*masktmp* $log_files
mv -f $cest/$sub/$ses/*.log $log_files
mv -f $cest/$sub/$ses/${sub}_$ses-B0MAP-pos.nii.gz $log_files
mv -f $cest/$sub/$ses/${sub}_$ses-B0MAP-thresh.nii.gz $log_files
mv -f $cest/$sub/$ses/${sub}_$ses-B1MAP-thresh.nii.gz $log_files

#######################################################################################################
## REGISTER ATLASES TO UNI IMAGES AND GLUCEST IMAGES ##

# inverse warp the atlaes to subject space
for roi in left right
do
  antsApplyTransforms -d 3 -r $structural/$sub/$ses/${sub}_$ses-INV2_corrected.nii.gz \
    -i $atlas/HarvardOxford/HarvardOxford-${roi}_hippocampus-thr25-0.7mm.nii.gz \
    -n MultiLabel \
    -o $cest/$sub/$ses/atlases/${sub}_$ses-HarvardOxford-${roi}_hippocampus.nii.gz \
    -t [$structural/$sub/$ses/MNI_transforms/${sub}_$ses-INV2inMNI-0GenericAffine.mat,1] \
    -t $structural/$sub/$ses/MNI_transforms/${sub}_$ses-INV2inMNI-1InverseWarp.nii.gz

  /project/bbl_projects/apps/melliott/scripts/extract_slice2.sh \
    -MultiLabel \
    $cest/$sub/$ses/atlases/${sub}_$ses-HarvardOxford-${roi}_hippocampus.nii.gz \
    $cest/$sub/$ses/${sub}_$ses-B0B1CESTMAP.nii \
    $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus.nii

  gzip $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus.nii

  fslmaths $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus.nii.gz \
    -mul $cest/$sub/$ses/${sub}_$ses-CEST-mask.nii.gz \
    $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_masked.nii.gz

  fslmaths $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_masked.nii.gz \
    -bin $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_mask.nii.gz

  fslmaths $cest/$sub/$ses/${sub}_$ses-GluCEST.nii.gz \
    -mul $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_mask.nii.gz \
    $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_cest.nii.gz

  fslmaths $cest/$sub/$ses/${sub}_$ses-B1MAP.nii \
    -mul $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_mask.nii.gz \
    $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_b1.nii.gz
  
  fslmaths $cest/$sub/$ses/${sub}_$ses-B0MAP.nii \
    -mul $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_mask.nii.gz \
    $cest/$sub/$ses/atlases/${sub}_$ses-2d-HarvardOxford-${roi}_hippocampus_b0.nii.gz

done

#######################################################################################################
echo -e "\n$sub $ses SUCCESFULLY PROCESSED\n\n\n"
} | tee "$logfile"
else
echo "$sub $ses is either missing data or already processed. Will not process"
sleep 1.5
fi
