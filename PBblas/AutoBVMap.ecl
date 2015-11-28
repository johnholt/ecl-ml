IMPORT Std.Str;
IMPORT std.system.Thorlib;
IMPORT PBblas;
dimension_t := PBblas.Types.dimension_t;
partition_t := PBblas.Types.partition_t;
IMPORT ML.MAT;

EXPORT AutoBVMap(dimension_t m_rows, dimension_t m_cols,
                  dimension_t f_b_rows=0, dimension_t f_b_cols=0,
                  UNSIGNED maxrows=1000, UNSIGNED maxcols=1000)
    := MODULE(PBblas.IMatrix_Map)
//  ASSERT(f_b_rows=0 OR f_b_cols=0 OR f_b_rows=m_rows OR f_b_cols=m_cols,
//          'Not a vector of blocks!', FAIL);
  SHARED nodes_available := Thorlib.nodes();
  SHARED VectorMap := MODULE
    SHARED entries := MAX(m_rows,1)*MAX(m_cols,1);
    SHARED max_entries_per_node := MIN(MAX(maxrows*maxcols,1000),10000);
    SHARED vector_size := MAX(MAP(f_b_cols = m_cols           => m_cols,
                                  f_b_rows = m_rows           => m_rows,
                                  m_cols < m_rows             => m_cols,
                                  m_rows),
                             1);
    SHARED vectors := MAX(MAP(f_b_cols = m_cols             => m_rows,
                              f_b_rows = m_rows             => m_cols,
                              m_cols < m_rows               => m_rows,
                              m_cols),
                          1);
    SHARED max_vectors_per_node := 1 + (max_entries_per_node-1) DIV vector_size;
    SHARED min_nodes := 1 + (vectors-1) DIV max_vectors_per_node;
    SHARED cycles := 1 + (min_nodes-1) DIV nodes_available;
    SHARED work_partitions := cycles * nodes_available;
    SHARED vectors_per_part := 1 + (vectors-1) DIV work_partitions;
    EXPORT full_block_rows := IF(m_rows=vector_size, m_rows, vectors_per_part);
    EXPORT full_block_cols := IF(m_cols=vector_size, m_cols, vectors_per_part);
  END; // VectorMap
  //
  SHARED this_node       := Thorlib.node();
  //
  EXPORT block_rows   := VectorMap.full_block_rows;
  EXPORT block_cols   := VectorMap.full_block_cols;
  EXPORT row_blocks   := ((m_rows-1) DIV block_rows) + 1;
  EXPORT col_blocks   := ((m_cols-1) DIV block_cols) + 1;
  //
  EXPORT matrix_rows  := m_rows;
  EXPORT matrix_cols  := m_cols;
  EXPORT partitions_used := row_blocks * col_blocks;
  EXPORT nodes_used   := MIN(nodes_available, partitions_used);
  // Functions.
  EXPORT row_block(dimension_t mat_row) := ((mat_row-1) DIV block_rows) + 1;
  EXPORT col_block(dimension_t mat_col) := ((mat_col-1) DIV block_cols) + 1;
  EXPORT assigned_part(dimension_t rb, dimension_t cb) := ((cb-1) * row_blocks) + rb;
  EXPORT assigned_node(partition_t p) := ((p-1) % nodes_used);
  EXPORT first_row(partition_t p)   := (((p-1)  %  row_blocks) * block_rows) + 1;
  EXPORT first_col(partition_t p)   := (((p-1) DIV row_blocks) * block_cols) + 1;
  EXPORT part_rows(partition_t p)   := MIN(matrix_rows-first_row(p)+1, block_rows);
  EXPORT part_cols(partition_t p)   := MIN(matrix_cols-first_col(p)+1, block_cols);
    
END;