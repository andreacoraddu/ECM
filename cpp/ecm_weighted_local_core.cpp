#include <cmath>
#include <algorithm>
#include <cstddef>

extern "C" int ecm_weighted_local_core(
    const double* V,
    std::size_t M,
    std::size_t N,
    const double* I,
    const unsigned char* fitMask,
    const double* W,
    double Vmin,
    double Vmax,
    double* OCV,
    double* Reff,
    double* R2) {

    if (!V || !I || !fitMask || !W || !OCV || !Reff || !R2) {
        return -1;
    }

    for (std::size_t i = 0; i < M; ++i) {
        double S0 = 0.0, S1 = 0.0, S2 = 0.0, T0 = 0.0, T1 = 0.0;
        std::size_t nValid = 0;

        for (std::size_t j = 0; j < N; ++j) {
            if (!fitMask[j]) {
                continue;
            }

            const std::size_t idx = i + j * M;
            const double y = V[idx];
            const double ii = I[j];
            const double w = W[idx];

            if (!std::isfinite(y) || !std::isfinite(ii) || !std::isfinite(w) || w <= 0.0) {
                continue;
            }

            S0 += w;
            S1 += w * ii;
            S2 += w * ii * ii;
            T0 += w * y;
            T1 += w * ii * y;
            ++nValid;
        }

        if (nValid < 2 || S0 <= 0.0) {
            OCV[i] = NAN;
            Reff[i] = NAN;
            R2[i] = NAN;
            continue;
        }

        const double det = S0 * S2 - S1 * S1;
        if (!std::isfinite(det) || std::abs(det) <= 1e-14) {
            OCV[i] = NAN;
            Reff[i] = NAN;
            R2[i] = NAN;
            continue;
        }

        const double beta = (S0 * T1 - S1 * T0) / det;
        const double alpha = (T0 - beta * S1) / S0;

        double ocv = std::max(Vmin, std::min(Vmax, alpha));
        double reff = std::max(1e-6, -beta);

        const double ybar = T0 / S0;
        double ssRes = 0.0;
        double ssTot = 0.0;

        for (std::size_t j = 0; j < N; ++j) {
            if (!fitMask[j]) {
                continue;
            }

            const std::size_t idx = i + j * M;
            const double y = V[idx];
            const double ii = I[j];
            const double w = W[idx];

            if (!std::isfinite(y) || !std::isfinite(ii) || !std::isfinite(w) || w <= 0.0) {
                continue;
            }

            const double yhat = alpha + beta * ii;
            const double er = y - yhat;
            const double et = y - ybar;
            ssRes += w * er * er;
            ssTot += w * et * et;
        }

        double r2 = 1.0;
        if (ssTot > 1e-14) {
            r2 = 1.0 - ssRes / ssTot;
        }

        OCV[i] = ocv;
        Reff[i] = reff;
        R2[i] = r2;
    }

    return 0;
}
