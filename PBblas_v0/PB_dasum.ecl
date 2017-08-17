// Absolute sum, the 1-norm
IMPORT $ AS PBblas_v0;
IMPORT PBblas_v0.IMatrix_Map;
IMPORT PBblas_v0.Types;
IMPORT PBblas_v0.Constants;
IMPORT Std.BLAS;
Part := Types.Layout_Part;
value_t := Types.value_t;
matrix_t := Types.matrix_t;

EXPORT value_t PB_dasum(PBblas_v0.IMatrix_Map x_map, DATASET(Part) X) := FUNCTION
  Work := RECORD
    value_t part_asum;
  END;
  Work asum(Part lr) := TRANSFORM
    SELF.part_asum := BLAS.dasum(lr.part_rows, lr.mat_part, 1);
  END;
  w0 := PROJECT(x, asum(LEFT));
  RETURN SUM(w0, part_asum);
END;
