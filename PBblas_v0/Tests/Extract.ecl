// Test triangle extractions
IMPORT $.^ AS PBblas_v0;
IMPORT PBblas_v0.Tests;
IMPORT PBblas_v0.Types;
IMPORT $.^.^.ML AS ML;
IMPORT ML.DMAT;
Layout_Cell := Types.Layout_Cell;
value_t := PBblas_v0.Types.value_t;
dimension_t := PBblas_v0.Types.dimension_t;
partition_t := PBblas_v0.Types.partition_t;
Triangle := PBblas_v0.Types.Triangle;
Upper:= PBblas_v0.Types.Triangle.Upper;
Lower:= PBblas_v0.Types.Triangle.Lower;
Unit_Diag := PBblas_v0.Types.Diagonal.UnitTri;
Real_Diag := PBblas_v0.Types.Diagonal.NotUnitTri;
// Test data generator and maps
Layout_Cell gen_1(UNSIGNED num_rows, UNSIGNED c, BOOLEAN trans,
                  REAL8 v):=TRANSFORM
  this_row := ((c-1) % num_rows) + 1;
  this_col := ((c-1) DIV num_rows) + 1;
  SELF.x := IF(trans, this_col, this_row);
  SELF.y := IF(trans, this_row, this_col);
  SELF.v := v;
END;
matmap_11:= PBblas_v0.matrix_map(11, 11, 4, 4);
ds := DATASET(121, gen_1(11, COUNTER, FALSE, (REAL8)COUNTER));
mat:= ML.DMAT.Converted.FromCells(matmap_11, ds);
upper_real:= PBblas_v0.PB_Extract_Tri(Upper,Real_Diag, matmap_11, mat);
out_upper_real := OUTPUT(upper_real, NAMED('Upper_Real_Diag'));
upper_unit:= PBblas_v0.PB_Extract_Tri(Upper,Unit_Diag, matmap_11, mat);
out_upper_unit := OUTPUT(upper_unit, NAMED('Upper_Unit_Diag'));
lower_real:= PBblas_v0.PB_Extract_Tri(Lower,Real_Diag, matmap_11, mat);
out_lower_real := OUTPUT(lower_real, NAMED('Lower_Real_Diag'));
lower_unit:= PBblas_v0.PB_Extract_Tri(Lower,Unit_Diag, matmap_11, mat);
out_lower_unit := OUTPUT(lower_unit, NAMED('Lower_Unit_Diag'));

EXPORT Extract := PARALLEL(out_upper_real, out_upper_unit,
                           out_lower_real, out_lower_unit);
