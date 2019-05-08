library( ANTsR )

baseDirectory <- './'
dataDirectory <- paste0( baseDirectory, 'Data/' )

outputDirectory <- './OutputANTsR/'
if( ! dir.exists( outputDirectory ) )
  {
  dir.create( outputDirectory )
  }
outputPrefix <- paste0( outputDirectory, 'antsr' )

inspiration <- antsImageRead( paste0( dataDirectory, "N25I_resampled.nii.gz" ) )
expiration <- antsImageRead( paste0( dataDirectory, "N25E_resampled.nii.gz" ) )

################
#
# Do some preprocessing
#   0. Rescale image intensities
#   1. Truncate image intensities
#   1. Denoise image
#

inspirationProcessed <- inspiration %>% iMath( "Normalize", 1 ) %>%
                         iMath( "TruncateIntensity", 0.05, 0.95 )
expirationProcessed <- expiration %>% iMath( "Normalize", 1 ) %>%
                         iMath( "TruncateIntensity", 0.05, 0.95 )

cat( "Denoise inspiration image." )
inspirationDenoised <- denoiseImage( inspirationProcessed, verbose = TRUE )
cat( "Denoise expiration image." )
expirationDenoised <- denoiseImage( expirationProcessed, verbose = TRUE )

##############
#
# Perform registration
#  * we don't perform any linear registration.  There really isn't a linear
#    transform between inspiratory and expiratory scans since the global
#    position of the body basically remains the same.  In the case below,
#    we use a coarse B-spline registration on the the downsampled image
#    which should account for those large inspiration/expiration differences.
#  * the meaning of each option is given in the antsRegistration help
#    i.e., 'antsRegistration --help 1'
#

registration <- antsRegistration( fixed = inspirationDenoised,
  moving = expirationDenoised, typeofTransform = "SyNOnly", verbose = TRUE )

plot( inspiration, registration$warpedmovout, color.overlay = "jet", alpha = 0.7 )
