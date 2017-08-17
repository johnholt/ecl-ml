//Function prototype for a function to apply to each element of the distributed matrix
IMPORT $ AS PBblas_v0;
value_t := PBblas_v0.Types.value_t;
dimension_t := PBblas_v0.Types.dimension_t;
partition_t := PBblas_v0.Types.partition_t;

EXPORT value_t IElementFunc(value_t v, dimension_t r, dimension_t c) := v;
