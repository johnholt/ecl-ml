IMPORT ML;

/* ********************************************************************************************************************* */

/**
 * This function ranks all elments across the cells of the matrix.
 *
 * WARNING: this function ranks the entire matrix.
 * If the desired behaviour is ranking only 1 variable than the data have to be previously filtered.
 *
 * @author  Custodio Jose Eleandro
 * @version 1.0
 *
 * @param A  is a matrix of data points.
 * @param groups  is the desired number of groups if none was especified the it is assumed the number of elements.
 * @param ties  is the strategy for tied data values. 'l'=mininum rank, 'm'=mean of the ranks, 'h'=maximum and 'o'=same order or do nothing.
 *              The default strategy is low.
 *
 */
export RankElements(DATASET(ML.Mat.Types.Element) A, UNSIGNED groups = 0,STRING1 ties='l') := FUNCTION
    
	sortedA := SORT(A, value);
	N := ML.Mat.Has(sortedA).Stats.NElements;
	fgroups := IF(groups = 0, N, groups);
	

	dense := PROJECT(
		sortedA,
		TRANSFORM(
		  {ML.Mat.Types.Element; REAL rankOrder},
			SELF.rankOrder := TRUNCATE(COUNTER * 1000 / (N + 1)),
			SELF := LEFT
		)
	);
	
	tiesGroups := TABLE(dense,{
			value,
			rankLow  := MIN(GROUP,rankOrder),
			rankMean := AVE(GROUP,rankOrder),
			rankHigh := MAX(GROUP,rankOrder)
		},
		value
	);  
	ranks := JOIN (dense, tiesGroups, LEFT.value = RIGHT.value, TRANSFORM(
		  ML.Mat.Types.Element,
		  SELF.x := LEFT.x;
		  SELF.y := LEFT.y;
		  SELF.value := map(
					ties = 'l' => RIGHT.rankLow,
					ties = 'm' => RIGHT.rankMean,
					ties = 'h' => RIGHT.rankHigh,
					ties = 'o' => LEFT.rankOrder,
					LEFT.rankOrder
			)
		)
	);
	RETURN ranks;
END;