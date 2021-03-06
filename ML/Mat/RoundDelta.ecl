IMPORT ML.Mat AS ML_Mat;
IMPORT ML.Mat.Types AS Types;
IMPORT Config FROM ML;
EXPORT RoundDelta(DATASET(Types.Element) d, REAL delta=Config.RoundingError) := PROJECT(d, TRANSFORM(Types.Element, 
																											SELF.value := IF(ABS(LEFT.value-ROUND(LEFT.value))<delta ,ROUND(LEFT.value), LEFT.value ), SELF := LEFT));