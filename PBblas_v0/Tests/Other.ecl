// Tests for Hadamard, Apply2Elements, PB_daxpy,
// PB_dscal, PB_dtran
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
matmap_11 := PBblas_v0.matrix_map(11, 11, 11, 11);
matmap_3  := PBblas_v0.matrix_map(11, 11, 3, 3);
//
// Generate transpose test data, and test PB_dtran
cell_tran_src := DATASET(121, gen_1(11, COUNTER, FALSE, (REAL8)COUNTER));
cell_tran_tgt := DATASET(121, gen_1(11, COUNTER, TRUE, (REAL8)COUNTER));
mat_11_tran_src:= ML.DMAT.Converted.FromCells(matmap_11, cell_tran_src);
mat_11_tran_tgt:= ML.DMAT.Converted.FromCells(matmap_11, cell_tran_tgt);
mat_3_tran_src := ML.DMAT.Converted.FromCells(matmap_3, cell_tran_src);
mat_3_tran_tgt := ML.DMAT.Converted.FromCells(matmap_3, cell_tran_tgt);
mat_11_tran := PBblas_v0.PB_dtran(matmap_11, matmap_11, -1, mat_11_tran_src, 2, mat_11_tran_tgt);
mat_3_tran := PBblas_v0.PB_dtran(matmap_3, matmap_3, -1, mat_3_tran_src, 2, mat_3_tran_tgt);
diff_tran_11 := Tests.DiffReport.Compare_Parts('Transpose, single', mat_11_tran_tgt, mat_11_tran);
diff_tran_3 := Tests.DiffReport.Compare_Parts('Transpose, multiple', mat_3_tran_tgt, mat_3_tran);
//
// generate test data and test Apply with PB_dscal
cell_apply_scale := DATASET(121, gen_1(11, COUNTER, FALSE, (REAL8) COUNTER));
value_t times_3(value_t v, dimension_t x, dimension_t y) := v*3;
mat_11_apply_scale := ML.DMAT.Converted.FromCells(matmap_11, cell_apply_scale);
mat_3_apply_scale := ML.DMAT.Converted.FromCells(matmap_3, cell_apply_scale);
mat_apply_11 := PBblas_v0.Apply2Elements(matmap_11, mat_11_apply_scale, times_3);
mat_apply_3 := PBblas_v0.Apply2Elements(matmap_3, mat_3_apply_scale, times_3);
mat_scale_11 := PBblas_v0.PB_daxpy(2.0, mat_11_apply_scale, mat_11_apply_scale);
mat_scale_3 := PBblas_v0.PB_daxpy(2.0, mat_3_apply_scale, mat_3_apply_scale);
diff_as_11 := Tests.DiffReport.Compare_Parts('Apply v. ax+y, single',mat_apply_11, mat_scale_11);
diff_as_3 := Tests.DiffReport.Compare_Parts('Apply v. ax+y, multiple', mat_apply_3, mat_scale_3);
//
// generate test data and test Hadamard and apply
cell_hprod := DATASET(121, gen_1(11, COUNTER, FALSE, (REAL8)COUNTER));
value_t sq(value_t v, dimension_t x, dimension_t y) := v*v;
mat_11_test_in := ML.DMAT.Converted.FromCells(matmap_11, cell_hprod);
mat_3_test_in := ML.DMAT.Converted.FromCells(matmap_3, cell_hprod);
mat_11_sq := PBblas_v0.Apply2Elements(matmap_11, mat_11_test_in, sq);
mat_3_sq := PBblas_v0.Apply2Elements(matmap_3, mat_3_test_in, sq);
mat_11_hprod := PBBlas_v0.HadamardProduct(matmap_11, mat_11_test_in, mat_11_test_in);
mat_3_hprod := PBblas_v0.HadamardProduct(matmap_3, mat_3_test_in, mat_3_test_in);
diff_hprod_11 := Tests.DiffReport.Compare_Parts('Hadamard test, single', mat_11_sq, mat_11_hprod);
diff_hprod_3 := Tests.DiffReport.Compare_Parts('Hadamard test, multiple', mat_3_sq, mat_3_hprod);
//
EXPORT Other := diff_hprod_3 + diff_hprod_11 + diff_as_3 + diff_as_11
              + diff_tran_3 + diff_tran_11;
