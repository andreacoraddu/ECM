#include "mex.h"
#include <stddef.h>

int ecm_weighted_local_core(
    const double* V,
    size_t M,
    size_t N,
    const double* I,
    const unsigned char* fitMask,
    const double* W,
    double Vmin,
    double Vmax,
    double* OCV,
    double* Reff,
    double* R2);

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 6) {
        mexErrMsgIdAndTxt("ecm_weighted_local_mex:nrhs", "Expected 6 inputs: V, I_A, fitMask, W, Vmin, Vmax.");
    }
    if (nlhs > 3) {
        mexErrMsgIdAndTxt("ecm_weighted_local_mex:nlhs", "Expected up to 3 outputs.");
    }

    const mxArray* Varr = prhs[0];
    const mxArray* Iarr = prhs[1];
    const mxArray* Marr = prhs[2];
    const mxArray* Warr = prhs[3];

    if (!mxIsDouble(Varr) || mxIsComplex(Varr) || !mxIsDouble(Iarr) || mxIsComplex(Iarr) ||
        !mxIsDouble(Warr) || mxIsComplex(Warr)) {
        mexErrMsgIdAndTxt("ecm_weighted_local_mex:type", "V, I_A and W must be real double arrays.");
    }

    const mwSize M = mxGetM(Varr);
    const mwSize N = mxGetN(Varr);

    if (mxGetM(Warr) != M || mxGetN(Warr) != N) {
        mexErrMsgIdAndTxt("ecm_weighted_local_mex:size", "W must have same size as V.");
    }

    if (mxGetNumberOfElements(Iarr) != N || mxGetNumberOfElements(Marr) != N) {
        mexErrMsgIdAndTxt("ecm_weighted_local_mex:size", "I_A and fitMask lengths must equal number of columns in V.");
    }

    const double* V = mxGetPr(Varr);
    const double* I = mxGetPr(Iarr);
    const double* W = mxGetPr(Warr);

    unsigned char* mask = (unsigned char*)mxCalloc(N, sizeof(unsigned char));
    if (mxIsLogical(Marr)) {
        const mxLogical* Mlog = mxGetLogicals(Marr);
        mwSize j;
        for (j = 0; j < N; ++j) {
            mask[j] = (unsigned char)(Mlog[j] ? 1 : 0);
        }
    } else {
        const double* Mnum = mxGetPr(Marr);
        mwSize j;
        for (j = 0; j < N; ++j) {
            mask[j] = (unsigned char)(Mnum[j] != 0.0);
        }
    }

    const double Vmin = mxGetScalar(prhs[4]);
    const double Vmax = mxGetScalar(prhs[5]);

    plhs[0] = mxCreateDoubleMatrix(M, 1, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(M, 1, mxREAL);
    plhs[2] = mxCreateDoubleMatrix(M, 1, mxREAL);

    {
        double* OCV = mxGetPr(plhs[0]);
        double* Reff = mxGetPr(plhs[1]);
        double* R2 = mxGetPr(plhs[2]);

        if (ecm_weighted_local_core(V, (size_t)M, (size_t)N, I, mask, W, Vmin, Vmax, OCV, Reff, R2) != 0) {
            mxFree(mask);
            mexErrMsgIdAndTxt("ecm_weighted_local_mex:core", "Core computation failed.");
        }
    }

    mxFree(mask);
}
