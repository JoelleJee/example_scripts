#!/bin/bash

#This script calculates GluCEST contrast and gray matter density measures

#######################################################################################################
## DEFINE PATHS ##

cest=$1 #path to processed GluCEST data
data=$2
outputpath=$3

# HARVARD OXFORD

for atlas in cort sub
do
	touch $outputpath/all-GluCEST-HarvardOxford-$atlas-measures.tsv
	echo "Subject	HarvardOxford_${atlas}_CEST_mean	HarvardOxford_CEST_numvoxels	HarvardOxford_CEST_SD" >> \
		$outputpath/all-GluCEST-HarvardOxford-$atlas-measures.tsv
done

for i in $(ls $cest)
do
	case=${i##*/}
	echo "CASE: $case"
	mkdir $outputpath/$case

	for atlas in cort sub
	do
		# quantify GluCEST contrast for each participant
		3dROIstats -mask $cest/$case/atlases/$case-2d-HarvardOxford-$atlas.nii.gz \
			-zerofill NaN -nomeanout -nzmean -nzsigma -nzvoxels -nobriklab -1DRformat \
			$cest/$case/$case-GluCEST.nii.gz >> $outputpath/$case/$case-HarvardOxfordROI-GluCEST-$atlas-measures.tsv
		#format participant-specific csv
		sed -i 's/name/Subject/g' $outputpath/$case/$case-HarvardOxfordROI-GluCEST-$atlas-measures.tsv
		cut -f2-3 --complement $outputpath/$case/$case-HarvardOxfordROI-GluCEST-$atlas-measures.tsv >> \
			$outputpath/$case/tmp.tsv
		mv $outputpath/$case/tmp.tsv $outputpath/$case/$case-HarvardOxfordROI-GluCEST-$atlas-measures.tsv

		# quantify GluCEST contrast for each participant (whole subcortical and cortical)
		3dROIstats -mask $cest/$case/atlases/$case-2d-HarvardOxford-$atlas-bin.nii.gz \
			-zerofill NaN -nomeanout -nzmean -nzsigma -nzvoxels -nobriklab -1DRformat \
			$cest/$case/$case-GluCEST.nii.gz >> $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv
		#format participant-specific csv
		sed -i 's/name/Subject/g' $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv
		cut -f2-3 --complement $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv >> \
			$outputpath/$case/tmp.tsv
		mv $outputpath/$case/tmp.tsv $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv
		#enter participant GluCEST contrast data into master spreadsheet
		sed -n "2p" $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv >> \
			$outputpath/all-GluCEST-HarvardOxford-$atlas-measures.tsv

		for structural in INV2 UNI
		do
			# quantify 3d contrast for each participant
			3dROIstats -mask $cest/$case/atlases/$case-HarvardOxford-$atlas.nii.gz \
				-zerofill NaN -nomeanout -nzmean -nzsigma -nzvoxels -nobriklab -1DRformat \
				$data/$case/$case-${structural}_corrected.nii.gz >> $outputpath/$case/$case-HarvardOxfordROI-${structural}-$atlas-measures.tsv
			#format participant-specific csv
			sed -i 's/name/Subject/g' $outputpath/$case/$case-HarvardOxfordROI-${structural}-$atlas-measures.tsv
			cut -f2-3 --complement $outputpath/$case/$case-HarvardOxfordROI-${structural}-$atlas-measures.tsv >> \
				$outputpath/$case/tmp.tsv
			mv $outputpath/$case/tmp.tsv $outputpath/$case/$case-HarvardOxfordROI-${structural}-$atlas-measures.tsv

		done
	done
done

