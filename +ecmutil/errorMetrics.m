function metrics = errorMetrics(y, yhat)
%ERRORMETRICS Compute RMSE, MAE, max absolute error and bias.
valid = isfinite(y) & isfinite(yhat);
e = y(valid) - yhat(valid);
if isempty(e)
    metrics.RMSE_V = NaN;
    metrics.MAE_V = NaN;
    metrics.MaxAbsError_V = NaN;
    metrics.Bias_V = NaN;
    metrics.NRMSE_V = NaN;
    metrics.MAPE_pct = NaN;
    metrics.R2 = NaN;
    metrics.P95AbsError_V = NaN;
    metrics.N = 0;
else
    yv = y(valid);
    metrics.RMSE_V = sqrt(mean(e.^2));
    metrics.MAE_V = mean(abs(e));
    metrics.MaxAbsError_V = max(abs(e));
    metrics.Bias_V = mean(e);
    yrange = max(yv) - min(yv);
    if yrange <= eps
        metrics.NRMSE_V = NaN;
    else
        metrics.NRMSE_V = metrics.RMSE_V / yrange;
    end

    nonzeroMask = abs(yv) > 1e-9;
    if any(nonzeroMask)
        metrics.MAPE_pct = 100*mean(abs(e(nonzeroMask)./yv(nonzeroMask)));
    else
        metrics.MAPE_pct = NaN;
    end

    ssRes = sum(e.^2);
    ssTot = sum((yv - mean(yv)).^2);
    if ssTot <= eps
        metrics.R2 = 1;
    else
        metrics.R2 = 1 - ssRes/ssTot;
    end

    metrics.P95AbsError_V = prctile(abs(e), 95);
    metrics.N = numel(e);
end
end
