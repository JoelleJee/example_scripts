case=$1
structural=$2
atlas=$3

if [ ! -d $structural/$case/MNI_transforms ]; then
  mkdir $structural/$case/MNI_transforms

  #register brain masked INV2 to upsampled MNI T1 template
  antsRegistrationSyN.sh -d 3 \
    -f $atlas/MNI/MNI152_T1_0.7mm_brain.nii.gz \
    -m $structural/$case/$case-INV2-hdbet_masked.nii.gz \
    -o $structural/$case/MNI_transforms/$case-INV2inMNI-

fi
