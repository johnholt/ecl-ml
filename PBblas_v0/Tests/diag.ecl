// Test for Diagonal
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
Diagonal := PBblas_v0.Types.Diagonal;
// Test data generator and maps
Layout_Cell gen_1(UNSIGNED num_rows, UNSIGNED c, BOOLEAN trans,
                  REAL8 v):=TRANSFORM
  this_row := ((c-1) % num_rows) + 1;
  this_col := ((c-1) DIV num_rows) + 1;
  SELF.x := IF(trans, this_col, this_row);
  SELF.y := IF(trans, this_row, this_col);
  SELF.v := v;
END;
matmap_cv := PBblas_v0.matrix_map(11, 1, 3, 1);
matmap_rv := PBblas_v0.matrix_map(1, 11, 1, 3);
matmap_m  := PBblas_v0.matrix_map(11, 11, 3, 3);

cell_c_vec := DATASET(11, gen_1(11, COUNTER, FALSE, (REAL8)COUNTER));
part_c_vec := ML.DMAT.Converted.FromCells(matmap_cv, cell_c_vec);
cell_r_vec := DATASET(11, gen_1(1, COUNTER, FALSE, (REAL8)COUNTER));
part_r_vec := ML.DMAT.Converted.FromCells(matmap_rv, cell_r_vec);

diag_c := PBblas_v0.Vector2Diag(matmap_cv, part_c_vec, matmap_m);
diag_r := PBblas_v0.Vector2Diag(matmap_rv, part_r_vec, matmap_m);
diff_diags := Tests.DiffReport.Compare_Parts('Diag test', diag_c, diag_r);
EXPORT diag := diff_diags;
