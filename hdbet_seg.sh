#!/bin/sh

case=$1
case_rawdata=$2
case_out=$3
hdbet_image=$4


# make output directoreis for subject/session
if [ ! -d $case_out ]; then
  mkdir $case_out -p
fi

# make output directories for fast and first segmentation
if [ ! -d $case_out/fast ]; then
  mkdir $case_out/fast/UNI -p
  mkdir $case_out/fast/INV2
fi
if [ ! -d $case_out/first ]; then
  mkdir $case_out/first/UNI -p
  mkdir $case_out/first/INV2
fi
if [ ! -d $case_out/log ]; then
  mkdir $case_out/log/UNI -p
  mkdir $case_out/log/INV2
fi

# convert and bias correct INV2 and UNI
for type in INV2 UNI; do
  if [ ! -e $case_out/$case-${type}_corrected.nii.gz ]; then
    N4BiasFieldCorrection -d 3 -i $case_rawdata/$case-$type.nii* \
      -o $case_out/$case-${type}_corrected.nii.gz
  fi
done

# brain mask the INV2 using hdbet
if [ ! -e $case_out/$case-INV2-hdbet_mask.nii.gz ]; then

  singularity run $hdbet_image \
    -i $case_out/$case-INV2_corrected.nii.gz \
    -o $case_out/$case-INV2-hdbet.nii.gz \
    -device cpu \
    -mode fast \
    -tta 0

fi

# apply the mask to corrected UNI and INV2
for type in INV2 UNI; do
  fslmaths $case_out/$case-${type}_corrected.nii.gz \
    -mas $case_out/$case-INV2-hdbet_mask.nii.gz \
    $case_out/$case-$type-hdbet_masked.nii.gz

  # run first
  if [ ! -e $case_out/first/$type/$case-$type-hdbet_masked_all_fast_firstseg.nii.gz ]; then
    run_first_all -b \
      -i $case_out/$case-$type-hdbet_masked.nii.gz \
      -o $case_out/first/$type/$case-$type-hdbet_masked
  fi

  # run fast
  if [ ! -e $case_out/fast/$type/$case-$type-hdbet_masked-fast_3_seg.nii.gz ]; then
    fast -n 3 \
      -o $case_out/fast/$type/$case-$type-hdbet_masked-fast_3 \
      $case_out/$case-$type-hdbet_masked.nii.gz
  fi

  # combine fast and first on UNI
  if [ ! -e $case_out/$type-hdbet_masked-fast_3_first_seg.nii.gz ]; then
    # binarize FIRST output to mask
    fslmaths $case_out/first/$type/$case-$type-hdbet_masked_all_fast_firstseg.nii.gz \
      -bin $case_out/log/$type/$case-$type-hdbet_masked_all_fast_firstseg_gm.nii.gz

    # remove FIRST mask from FAST 3 seg image by creating an inverse map
    # (*neg.nii.gz - GM=0, else=1) then multiplying
    fslmaths $case_out/log/$type/$case-$type-hdbet_masked_all_fast_firstseg_gm.nii.gz \
      -mul -1 \
      -add 1 $case_out/log/$type/$case-$type-hdbet_masked_all_fast_firstseg_gm_neg.nii.gz

    fslmaths $case_out/log/$type/$case-$type-hdbet_masked_all_fast_firstseg_gm_neg.nii.gz \
      -mul $case_out/fast/$type/$case-$type-hdbet_masked-fast_3_seg.nii.gz \
      $case_out/log/$type/$case-$type-hdbet_masked-fast_3_seg_neg.nii.gz

    # add FIRST mask back in as GM=2 to match with FAST 3 seg (CSF=1, GM=2, WM=3)
    fslmaths $case_out/log/$type/$case-$type-hdbet_masked_all_fast_firstseg_gm.nii.gz \
      -mul 2 \
      -add $case_out/log/$type/$case-$type-hdbet_masked-fast_3_seg_neg.nii.gz \
      $case_out/$case-$type-hdbet_masked-fast_3_first_seg.nii.gz
  fi

done

