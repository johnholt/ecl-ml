//Transpose a dense matrix using PB BLAS routines
IMPORT PBblas_v0;
IMPORT PBblas_v0.Types;
IMPORT PBblas_v0.IMatrix_Map;
Part := Types.Layout_Part;
EXPORT Trans := MODULE
  EXPORT TranMap(IMatrix_Map a_map) := FUNCTION
    RETURN PBblas_v0.Matrix_Map(a_map.matrix_cols, a_map.matrix_rows,
                             a_map.part_cols(1),a_map.part_rows(1));
  END;

  EXPORT DATASET(Part) matrix(IMatrix_Map a_map, DATASET(Part) a) := FUNCTION
    c_map := TranMap(a_map);
    RETURN PBblas_v0.PB_dtran(a_map, c_map, 1.0, a);
  END;
END;
