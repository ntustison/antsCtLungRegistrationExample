#!/bin/sh
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4

baseDirectory=./
dataDirectory="${baseDirectory}/Data/"
outputDirectory="${baseDirectory}/Output/"
outputPrefix="${outputDirectory}/N25IxE"

mkdir -p $outputDirectory

inspiration="${dataDirectory}/N25I_resampled.nii.gz"
expiration="${dataDirectory}/N25E_resampled.nii.gz"

inspirationMask="${dataDirectory}/N25I_resampledLungMask.nii.gz"
expirationMask="${dataDirectory}/N25E_resampledLungMask.nii.gz"

inspirationPreprocessed="${outputDirectory}/N25I_preprocessed.nii.gz"
expirationPreprocessed="${outputDirectory}/N25E_preprocessed.nii.gz"

################
#
# Do some preprocessing
#   0. Rescale image intensities
#   1. Truncate image intensities
#   1. Denoise image
#

if [[ ! -f $inspirationPreprocessed ]] || [[ ! -f $expirationPreprocessed ]];
  then
    echo "Preprocessing:  Rescale image intensities."

    ImageMath 3 $inspirationPreprocessed RescaleImage $inspiration 0 1
    ImageMath 3 $expirationPreprocessed RescaleImage $expiration 0 1

    echo "Preprocessing:  Truncate image intensities."

    ImageMath 3 $inspirationPreprocessed TruncateImageIntensity $inspirationPreprocessed
    ImageMath 3 $expirationPreprocessed TruncateImageIntensity $expirationPreprocessed

    echo "Preprocessing:  Denoise."

    DenoiseImage -d 3 -v 1 -i $inspirationPreprocessed -o $inspirationPreprocessed
    DenoiseImage -d 3 -v 1 -i $expirationPreprocessed -o $expirationPreprocessed
  fi


##############
#
# Perform registration one lung at a time
#  * we don't perform any linear registration.  There really isn't a linear
#    transform between inspiratory and expiratory scans since the global
#    position of the body basically remains the same.  In the case below,
#    we use a coarse B-spline registration on the the downsampled image
#    which should account for those large inspiration/expiration differences.
#  * the meaning of each option is given in the antsRegistration help
#    i.e., 'antsRegistration --help 1'
#  * '1' and '2' are the labels of the left and right lungs, respectively
#

for i in 1 2;
  do
    tmpInspirationLung="${outputDirectory}/tmpInspirationLung.nii.gz"
    tmpExpirationLung="${outputDirectory}/tmpExpirationLung.nii.gz"
    tmpInspirationLungMask="${outputDirectory}/tmpInspirationLungMask.nii.gz"
    tmpExpirationLungMask="${outputDirectory}/tmpExpirationLungMask.nii.gz"

    ThresholdImage 3 $inspirationMask $tmpInspirationLungMask $i $i 1 0
    ThresholdImage 3 $expirationMask $tmpExpirationLungMask $i $i 1 0

    ImageMath 3 $tmpInspirationLungMask MD $tmpInspirationLungMask 10
    ImageMath 3 $tmpExpirationLungMask MD $tmpExpirationLungMask 10

    ImageMath 3 $tmpInspirationLung m $tmpInspirationLungMask $inspirationPreprocessed
    ImageMath 3 $tmpExpirationLung m $tmpExpirationLungMask $expirationPreprocessed

    warpFieldPrefix=${outputPrefix}Lung${i}

    antsRegistration -d 3 \
                     -v 1 \
                     -t BSplineSyN[0.1,80,0,3] \
                     -m MSQ[${tmpInspirationLung},${tmpExpirationLung},1,1] \
                     -c 100x100x100x50x0 \
                     -f 8x6x4x2x1 \
                     -s 2x1x0x0x0 \
                     -o ${warpFieldPrefix}

    # split the warps into components and mask out displacement field outside lung

    ThresholdImage 3 $inspirationMask $tmpInspirationLungMask $i $i 1 0
    ThresholdImage 3 $expirationMask $tmpExpirationLungMask $i $i 1 0

    ConvertImage 3 ${warpFieldPrefix}0Warp.nii.gz ${warpFieldPrefix}0Warp 10
    ConvertImage 3 ${warpFieldPrefix}0InverseWarp.nii.gz ${warpFieldPrefix}0InverseWarp 10

    for j in xvec yvec zvec;
      do
        ImageMath 3 ${warpFieldPrefix}0Warp${j}.nii.gz m ${warpFieldPrefix}0Warp${j}.nii.gz $tmpInspirationLungMask
        ImageMath 3 ${warpFieldPrefix}0InverseWarp${j}.nii.gz m ${warpFieldPrefix}0InverseWarp${j}.nii.gz $tmpExpirationLungMask
      done

    ConvertImage 3 ${warpFieldPrefix}0Warp ${warpFieldPrefix}0Warp.nii.gz 9
    ConvertImage 3 ${warpFieldPrefix}0InverseWarp ${warpFieldPrefix}0InverseWarp.nii.gz 9

    rm -f $tmpInspirationLung
    rm -f $tmpExpirationLung
    rm -f $tmpInspirationLungMask
    rm -f $tmpExpirationLungMask

  done

## Combine the two warp fields

antsApplyTransforms -d 3 -v 1 \
                    -o [${outputPrefix}0Warp.nii.gz,1] \
                    -r $inspirationPreprocessed \
                    -t ${outputPrefix}Lung10Warp.nii.gz \
                    -t ${outputPrefix}Lung20Warp.nii.gz

antsApplyTransforms -d 3 -v 1 \
                    -o [${outputPrefix}0InverseWarp.nii.gz,1] \
                    -r $inspirationPreprocessed \
                    -t ${outputPrefix}Lung10InverseWarp.nii.gz \
                    -t ${outputPrefix}Lung20InverseWarp.nii.gz

## Fit displacement field, if desired

tmpInspirationLungMask="${outputDirectory}/tmpInspirationLungMask.nii.gz"
tmpExpirationLungMask="${outputDirectory}/tmpExpirationLungMask.nii.gz"

ThresholdImage 3 $inspirationMask $tmpInspirationLungMask 0 0 0 1
ThresholdImage 3 $expirationMask $tmpExpirationLungMask 0 0 0 1

SmoothDisplacementField 3 ${outputPrefix}0Warp.nii.gz \
                          ${outputPrefix}0Warp.nii.gz \
                          4x4x4 8 3 \
                          $tmpInspirationLungMask

SmoothDisplacementField 3 ${outputPrefix}0InverseWarp.nii.gz \
                          ${outputPrefix}0InverseWarp.nii.gz \
                          4x4x4 8 3 \
                          $tmpExpirationLungMask

rm -f $tmpInspirationLungMask
rm -f $tmpExpirationLungMask
rm -f ${outputPrefix}Lung*Warp.nii.gz


