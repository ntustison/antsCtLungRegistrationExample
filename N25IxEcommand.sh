#!/bin/sh
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=2

baseDirectory=./
dataDirectory="${baseDirectory}/Data/"
outputDirectory="${baseDirectory}/Output/"
outputPrefix=${outputDirectory}/

mkdir -p $outputDirectory

inspiration="${dataDirectory}/N25I_resampled.nii.gz"
expiration="${dataDirectory}/N25E_resampled.nii.gz"

inspirationPreprocessed="${outputDirectory}/N25I_preprocessed.nii.gz"
expirationPreprocessed="${outputDirectory}/N25E_preprocessed.nii.gz"


################
#
# Do some preprocessing
#   0. Rescale image intensities
#   1. Truncate image intensities
#   1. Denoise image
#

echo "Preprocessing:  Rescale image intensities."

ImageMath 3 $inspirationPreprocessed RescaleImage $inspiration 0 1
ImageMath 3 $expirationPreprocessed RescaleImage $expiration 0 1

echo "Preprocessing:  Truncate image intensities."

ImageMath 3 $inspirationPreprocessed TruncateImageIntensity $inspirationPreprocessed
ImageMath 3 $expirationPreprocessed TruncateImageIntensity $expirationPreprocessed

echo "Preprocessing:  Denoise."

DenoiseImage -d 3 -v 1 -i $inspirationPreprocessed -o $inspirationPreprocessed
DenoiseImage -d 3 -v 1 -i $expirationPreprocessed -o $expirationPreprocessed

##############
#
# Perform registration
#  * we don't perform any linear registration prior.  perhaps we should do
#    affine.  In the case below, we use a coarse B-spline registration on the
#    the downsampled image which should account for those large inspiration/
#    expiration differences.
#  * the meaning of each option is given in the antsRegistration help
#    i.e., 'antsRegistration -h 1'
#

antsRegistration -d 3 \
                 -v 1 \
                 -t BSplineSyN[0.1,80,0,3] \
                 -m MSQ[${inspirationPreprocessed},${expirationPreprocessed},1,1] \
                 -c 200x200x100x100x50 \
                 -f 8x6x4x2x1 \
                 -s 2x1x0x0x0 \
                 -o [/Users/ntustison/Data/Eduardo/Registrations/N25//N25IxE,/Users/ntustison/Data/Eduardo/Registrations/N25//N25IxEWarped.nii.gz]

