// Test the 1-norm, dasum
IMPORT $.^ AS PBblas_v0;
IMPORT PBblas_v0.Tests;
IMPORT PBblas_v0.Types;
IMPORT $.^.^.ML AS ML;
IMPORT ML.DMAT;
Layout_Cell := Types.Layout_Cell;
// Test data generator and maps
Layout_Cell gen_1(UNSIGNED num_rows, UNSIGNED c, BOOLEAN trans,
                  REAL8 v):=TRANSFORM
  this_row := ((c-1) % num_rows) + 1;
  this_col := ((c-1) DIV num_rows) + 1;
  SELF.x := IF(trans, this_col, this_row);
  SELF.y := IF(trans, this_row, this_col);
  SELF.v := v;
END;
matmap_3  := PBblas_v0.matrix_map(11, 1, 3, 1);
// Test dasum
mat_3_cells := DATASET(11, gen_1(11, COUNTER, FALSE, IF(COUNTER%2=0, 2, -2)));
mat_3 := ML.DMAT.Converted.FromCells(matmap_3, mat_3_cells);
mat_3_1norm := PBblas_v0.PB_dasum(matmap_3, mat_3);
EXPORT Norm1 := OUTPUT(mat_3_1norm, NAMED('Equals_22'));
