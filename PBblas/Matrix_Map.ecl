// Define processor grid template, and matrix mapping functions
IMPORT std.system.Thorlib;
IMPORT PBblas;
dimension_t := PBblas.Types.dimension_t;
partition_t := PBblas.Types.partition_t;

EXPORT Matrix_Map(dimension_t m_rows, dimension_t m_cols,
                  dimension_t f_b_rows=0, dimension_t f_b_cols=0)
                  := MODULE(PBblas.IMatrix_Map)
  SHARED nodes_available := Thorlib.nodes();
  SHARED this_node       := Thorlib.node();
  //
  SHARED node_layouts := DICTIONARY([{10 => 5, 10}
                               , {12 => 4, 6}
                               , {20 => 5, 10}
                               , {40 => 8, 10}
                               , {50 => 10, 25}
                               , {100 => 10, 20}
                               , {200 => 20, 50}
                               , {400 => 20, 40}
                               ], {UNSIGNED2 nodes => UNSIGNED2 sq, UNSIGNED2 rt});
  SHARED fat_layout := IF(m_rows>m_cols, m_rows<3*m_cols, m_cols<3*m_rows);
  SHARED skinny_layout := IF(m_rows>m_cols, m_rows<30*m_cols, m_cols<30*m_cols);
  SHARED skinny_5wide := nodes_available > 200 AND nodes_available % 5 = 0;
  SHARED skinny_4wide := nodes_available > 200 AND nodes_available % 4 = 0;
  SHARED skinny_major := MAP(nodes_available < 20     => nodes_available,
                             skinny_5wide             => nodes_available DIV 5,
                             skinny_4wide             => nodes_available DIV 4,
                             nodes_available % 3 = 0  => nodes_available DIV 3,
                             nodes_available % 2 = 0  => nodes_available DIV 2,
                             nodes_available);
  SHARED def_layout := nodes_available IN node_layouts;
  SHARED node_layout := node_layouts[nodes_available];
  SHARED major_axis:= MAP( skinny_layout              => skinny_major,
                           def_layout AND fat_layout  => node_layout.sq,
                           def_layout                 => node_layout.rt,
                           // more cases needed
                           skinny_major);
  SHARED minor_axis:= nodes_available DIV major_axis;
  SHARED major_cyc := 1 + (MAX(m_rows,m_cols)-1) DIV major_axis*1000;
  SHARED minor_cyc := 1 + (MIN(m_rows,m_cols)-1) DIV minor_axis*1000;
  SHARED major_dim := major_cyc * major_axis;
  SHARED minor_dim := minor_cyc * minor_axis;
  SHARED major_rows:= (m_rows+major_dim-1) DIV major_dim;
  SHARED major_cols:= (m_cols+major_dim-1) DIV major_dim;
  SHARED minor_rows:= (m_rows+minor_dim-1) DIV minor_dim;
  SHARED minor_cols:= (m_cols+minor_dim-1) DIV minor_dim;
  SHARED full_block_rows := MAP(m_rows<100    => m_rows,
                                m_rows>m_cols => major_rows,
                                minor_rows);
  SHARED full_block_cols := MAP(m_cols<100    => m_cols,
                                m_cols>m_rows => major_cols,
                                minor_cols);
  //
  EXPORT block_rows   := IF(f_b_rows=0, full_block_rows, f_b_rows);
  EXPORT block_cols   := IF(f_b_cols=0, full_block_cols, f_b_cols);
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