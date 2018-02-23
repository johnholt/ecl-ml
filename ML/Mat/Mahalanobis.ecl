IMPORT ML;

/**
 * Calculate the cumulative probability for x in df degrees of freedom 
 * 
 * @author  Custodio Jose Eleandro
 * @version 1.0
 *
 * @param df  Degrees of freedom
 * @param x   chi-squared distributed value
 * @return cumulative probability for x in df degrees of freedom 
 */
ChiSquareCDF(INTEGER df, REAL x) := FUNCTION
	RETURN ML.Utils.lowerGamma(df / 2, x / 2) / ML.Utils.gamma(df / 2);
END;

/**
 * This function calculates the Mahanlanobis distance over a collection of data points represented as matrix.
 * 
 *
 * @author  Custodio Jose Eleandro
 * @version 1.0
 *
 * @param A  matrix of points - every row represent an observation and every column as variable
 * @param sensitivity  Cuffoff point to considere an obaservation an outlier.
 *                     Ex. 0.05 means that every point above 95% of probability will be considered outlier.
 *
 * @return dsq  DATASET containing the Mahalanobis distance
 * @return prob DATASET containing the chisquared probability for that distance and degree of freedom;
 * @return is_outlier  DATASET containing 1's for outliers and 0's otherwise
 */
Export Mahalanobis(DATASET(ML.Mat.Types.Element) A, REAL sensitivity = 0.05) := MODULE
	// Transforming the data into PCA componentes. This step will remove correlation betwen points
	ZComp := ML.Mat.Pca(A).ZComp;

	// Calculate sample standard deviation for each column
	stdev := TABLE(ZComp, {
		y;
		stdev:= SQRT(SUM(GROUP, value * value)/(MAX(GROUP, x)-1 ));
	}, y);

	//Since componentes are not normalize, normalized it using sample standard deviation.
	ZCompNorm := PROJECT(JOIN(ZComp, stdev, LEFT.y = RIGHT.y), TRANSFORM(
		ML.Mat.Types.Element,
		SELF.x := LEFT.x;
		SELF.y := LEFT.y;
		SELF.value := LEFT.value / LEFT.stdev;
	));

	//  Mahalanobis distance is the sum of squared of the normalized componentes (D^2 = sum(normalized comp^2))
	EXPORT dsq := PROJECT(
		TABLE(ZCompNorm, {x;dsq := SUM(GROUP, value * value);}, x),
		TRANSFORM(
			ML.Mat.Types.Element,
			SELF.x := LEFT.x;
			SELF.y := 1;
			SELF.value := LEFT.dsq;
		)
	);

	// Calculates how many degrees of freedom we are dealing with
	df := ML.Mat.Has(A).Stats.YMax;
	

	// dsq is  chisquared distribuited, so it is possible to turn it distances into probabilities using X^2 CDF function
	// and according to normal assumptions it could be interpretated as probability of being outlier.
	EXPORT prob := PROJECT(dsq, TRANSFORM(
		ML.Mat.Types.Element,
		SELF.x := LEFT.x;
		SELF.y := 1;
		SELF.value := ChiSquareCDF(df, LEFT.value);
	));	
	

	// Verifies if p-value of each DSQ exceeds defined sensitivity
	EXPORT is_outlier := PROJECT(prob, TRANSFORM(
		ML.Mat.Types.Element,
		SELF.x := LEFT.x;
		SELF.y := 1;
		SELF.value := IF(LEFT.value > (1 - sensitivity), 1, 0);
	));
END;