//Apply a function to each element of the matrix
IMPORT $ AS PBblas_v0;
IMPORT PBblas_v0.IMatrix_Map;
IMPORT PBblas_v0.Types;
IMPORT PBblas_v0.Constants;
IMPORT Std.BLAS;
//Alias entries for convenience
Part := Types.Layout_Part;
value_t := Types.value_t;
IFunc := PBblas_v0.IElementFunc;
dim_t := PBblas_v0.Types.dimension_t;

EXPORT DATASET(Part)
      Apply2Elements(IMatrix_Map x_map, DATASET(Part) X, IFunc f) := FUNCTION
  Elem := {value_t v};  //short-cut record def
  Elem applyF(Elem e, Part p, UNSIGNED pos) := TRANSFORM
    r := ((pos-1)  %  p.part_rows) + p.first_row;
    c := ((pos-1) DIV p.part_rows) + p.first_col;
    SELF.v := f(e.v, r, c);
  END;
  Part apply_func(Part lr) := TRANSFORM
    elems := DATASET(lr.mat_part, Elem);
    new_elems := PROJECT(elems, applyF(LEFT, lr, COUNTER));
    SELF.mat_part := SET(new_elems, v);
    SELF := lr;
  END;
  RETURN PROJECT(X, apply_func(LEFT));
END;
