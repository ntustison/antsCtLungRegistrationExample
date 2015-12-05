# antsCtLungRegistrationExample

_Just some notes on CT lung registration_


# Mask + separate lung registration

* ``N25IxE_SplitLungRegistrationCommand.sh``
* [lung mask](https://github.com/ntustison/LungAndLobeEstimationExample).
* Separate left/right lung registrations and then combination of the warp fields using ``SmoothDisplacementField``.

# EMPIRE10 Results

* [Original ANTs](http://empire10.isi.uu.nl/staticpdf/article_picslexp.pdf) (``ANTS.cxx``)
* [New ANTs](http://empire10.isi.uu.nl/pdf/article_antsregistrationgaussiansyn.pdf) (``antsRegistration.cxx``)

