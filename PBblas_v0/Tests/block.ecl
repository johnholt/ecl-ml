// Test block vector function BVMM and BVRK
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
// Test data generator and maps
Layout_Cell gen_1(UNSIGNED num_rows, UNSIGNED c, BOOLEAN trans,
                  REAL8 v):=TRANSFORM
  this_row := ((c-1) % num_rows) + 1;
  this_col := ((c-1) DIV num_rows) + 1;
  SELF.x := IF(trans, this_col, this_row);
  SELF.y := IF(trans, this_row, this_col);
  SELF.v := v;
END;
matmap_7 := PBblas_v0.matrix_map(7, 4, 4, 4);
matmap_4 := PBblas_v0.matrix_map(4, 4, 4, 4);
cell_7 := DATASET(28, gen_1(7, COUNTER, FALSE, (REAL8)COUNTER));
cell_4 := DATASET(16, gen_1(4, COUNTER, FALSE, 1.0));
mat_7 := ML.DMAT.Converted.FromCells(matmap_7, cell_7);
mat_4 := ML.DMAT.Converted.FromCells(matmap_4, cell_4);
// Make the standard and run the tests
base := PBblas_v0.PB_dgemm(TRUE, FALSE, 1.0, matmap_7, mat_7, matmap_7,
                           mat_7, matmap_4, mat_4, -1.0);
bvrk := PBblas_v0.PB_dbvrk(TRUE, 1.0, matmap_7, mat_7, matmap_4, -1.0, mat_4);
bvmm := PBblas_v0.PB_dbvmm(TRUE, FALSE, 1.0, matmap_7, mat_7, matmap_7,
                           mat_7, matmap_4, mat_4, -1.0);
diff_bvrk := Tests.DiffReport.Compare_Parts('DBVRK test', base, bvrk);
diff_bvmm := Tests.DiffReport.Compare_Parts('DBVMM test', base, bvmm);

EXPORT block := diff_bvrk + diff_bvmm;