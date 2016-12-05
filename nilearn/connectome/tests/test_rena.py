from nose.tools import assert_equal, assert_true, assert_raises

import numpy as np
from sklearn.externals.joblib import Memory
from nilearn._utils.testing import generate_fake_fmri
from nilearn.connectome import ReNA
from nilearn.input_data import NiftiMasker


def test_rena_clusterings():
    data, mask_img = generate_fake_fmri(shape=(10, 11, 12), length=5)

    nifti_masker = NiftiMasker(mask_img=mask_img).fit()
    rena = ReNA(n_clusters=10, mask=nifti_masker, scaling=False)

    data_red = rena.fit_transform(data)
    data_compress = rena.inverse_transform(data_red)

    assert_equal(10, rena.n_clusters_)

    memory = Memory(cachedir=None)
    rena2 = ReNA(n_clusters=-2, mask=nifti_masker, memory=memory)
    assert_raises(ValueError, rena2.fit, data)

    rena3 = ReNA(n_clusters=10, mask=None, scaling=True).fit(data)
