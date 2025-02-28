// RUN: mlir-hlo-opt %s --legalize-mhlo-to-thlo | FileCheck %s

// CHECK-LABEL: @dynamic_broadcast_in_dim
// CHECK-SAME:  %[[ARG:.*]]: tensor<?x?xf32>, %[[SHAPE:.*]]: tensor<3xindex>
func.func @dynamic_broadcast_in_dim(%arg : tensor<?x?xf32>, %shape : tensor<3xindex>) -> tensor<?x?x?xf32> {
  // CHECK-DAG: %[[C0:.*]] = arith.constant 0
  // CHECK-DAG: %[[C1:.*]] = arith.constant 1
  // CHECK-DAG: %[[C2:.*]] = arith.constant 2
  // CHECK-DAG: %[[SHAPE_D0:.*]] = tensor.extract %[[SHAPE]][%[[C0]]]
  // CHECK-DAG: %[[SHAPE_D1:.*]] = tensor.extract %[[SHAPE]][%[[C1]]]
  // CHECK-DAG: %[[SHAPE_D2:.*]] = tensor.extract %[[SHAPE]][%[[C2]]]
  // CHECK-DAG: %[[INIT:.*]] = linalg.init_tensor [%[[SHAPE_D0]], %[[SHAPE_D1]], %[[SHAPE_D2]]] : tensor<?x?x?xf32>
  // CHECK-NEXT: %[[BCAST:.*]] = thlo.dynamic_broadcast_in_dim
  // CHECK-SAME: ins(%[[ARG]] : tensor<?x?xf32>)
  // CHECK-SAME: outs(%[[INIT]] : tensor<?x?x?xf32>)
  // CHECK-SAME: {broadcast_dimensions = [:i64 0, 2]}
  // CHECK:     return %[[BCAST]]
  %0 = "mhlo.dynamic_broadcast_in_dim"(%arg, %shape)
      { broadcast_dimensions = dense<[0, 2]> : tensor<2xi64> }
      : (tensor<?x?xf32>, tensor<3xindex>) -> tensor<?x?x?xf32>
  func.return %0 : tensor<?x?x?xf32>
}

// CHECK-LABEL: @dynamic_broadcast_in_dim_expansion_behavior_known
// CHECK-SAME:  %[[ARG:.*]]: tensor<?x?xf32>, %[[SHAPE:.*]]: tensor<3xindex>
func.func @dynamic_broadcast_in_dim_expansion_behavior_known(
    %arg : tensor<?x?xf32>, %shape : tensor<3xindex>) -> tensor<?x?x?xf32> {
  // CHECK:       %[[BCAST:.*]] = "mhlo.dynamic_broadcast_in_dim"(%[[ARG]], %[[SHAPE]])
  // CHECK:       return %[[BCAST]]
  %0 = "mhlo.dynamic_broadcast_in_dim"(%arg, %shape) {
      broadcast_dimensions = dense<[0, 2]> : tensor<2xi64>,
      known_expanding_dimensions = dense<[0]> : tensor<1xi64>,
      known_nonexpanding_dimensions = dense<[1]> : tensor<1xi64> }
      : (tensor<?x?xf32>, tensor<3xindex>) -> tensor<?x?x?xf32>
  func.return %0 : tensor<?x?x?xf32>
}

// CHECK-LABEL: @dynamic_broadcast_in_dim_with_known_expanding
// CHECK-SAME:  %[[ARG:.*]]: tensor<?x?x?xf32>, %[[SHAPE:.*]]: tensor<4xindex>
func.func @dynamic_broadcast_in_dim_with_known_expanding(%arg : tensor<?x?x?xf32>, %shape : tensor<4xindex>) -> tensor<?x?x?x?xf32> {
  // CHECK-DAG: %[[C0:.*]] = arith.constant 0
  // CHECK-DAG: %[[C1:.*]] = arith.constant 1
  // CHECK-DAG: %[[C2:.*]] = arith.constant 2
  // CHECK-DAG: %[[C3:.*]] = arith.constant 3
  // CHECK-DAG: %[[SHAPE_D0:.*]] = tensor.extract %[[SHAPE]][%[[C0]]]
  // CHECK-DAG: %[[SHAPE_D1:.*]] = tensor.extract %[[SHAPE]][%[[C1]]]
  // CHECK-DAG: %[[SHAPE_D2:.*]] = tensor.extract %[[SHAPE]][%[[C2]]]
  // CHECK-DAG: %[[SHAPE_D3:.*]] = tensor.extract %[[SHAPE]][%[[C3]]]
  // CHECK-DAG: %[[INIT:.*]] = linalg.init_tensor [%[[SHAPE_D0]], %[[SHAPE_D1]], %[[SHAPE_D2]], %[[SHAPE_D3]]] : tensor<?x?x?x?xf32>
  // CHECK-NEXT: %[[BCAST:.*]] = thlo.dynamic_broadcast_in_dim
  // CHECK-SAME: ins(%[[ARG]] : tensor<?x?x?xf32>)
  // CHECK-SAME: outs(%[[INIT]] : tensor<?x?x?x?xf32>)
  // CHECK-SAME: {broadcast_dimensions = [:i64 0, 2, 3], known_expanding_dimensions = [:i64 0], known_nonexpanding_dimensions = [:i64 2]}
  // CHECK:     return %[[BCAST]]
  %0 = "mhlo.dynamic_broadcast_in_dim"(%arg, %shape) {
      broadcast_dimensions = dense<[0, 2, 3]> : tensor<3xi64>,
      known_expanding_dimensions = dense<[0]> : tensor<1xi64>,
      known_nonexpanding_dimensions = dense<[2]> : tensor<1xi64> }
      : (tensor<?x?x?xf32>, tensor<4xindex>) -> tensor<?x?x?x?xf32>
  func.return %0 : tensor<?x?x?x?xf32>
}

// CHECK-LABEL: @concatenate
// CHECK-SAME:  %[[A:.*]]: tensor<?x?xi32>, %[[B:.*]]: tensor<?x?xi32>, %[[C:.*]]: tensor<?x?xi32>
func.func @concatenate(%a: tensor<?x?xi32>, %b: tensor<?x?xi32>, %c: tensor<?x?xi32>) -> tensor<?x?xi32> {
  // CHECK-DAG:  %[[C0:.*]] = arith.constant 0
  // CHECK-DAG:  %[[C1:.*]] = arith.constant 1
  // CHECK-DAG:  %[[D0:.*]] = tensor.dim %[[A]], %[[C0]]
  // CHECK-DAG:  %[[CONCAT_DIM_A:.*]] = tensor.dim %[[A]], %[[C1]]
  // CHECK-DAG:  %[[CONCAT_DIM_B:.*]] = tensor.dim %[[B]], %[[C1]]
  // CHECK-DAG:  %[[CONCAT_DIM_C:.*]] = tensor.dim %[[C]], %[[C1]]
  // CHECK-DAG:  %[[CONCAT_DIM_AB:.*]] = arith.addi %[[CONCAT_DIM_A]], %[[CONCAT_DIM_B]]
  // CHECK-DAG:  %[[CONCAT_DIM_ABC:.*]] = arith.addi %[[CONCAT_DIM_AB]], %[[CONCAT_DIM_C]]
  // CHECK-DAG:  %[[INIT:.*]] = linalg.init_tensor [%[[D0]], %[[CONCAT_DIM_ABC]]]
  // CHECK:      %[[CONCATENATE:.*]] = thlo.concatenate
  // CHECK-SAME:     ins(%[[A]] : tensor<?x?xi32>, %[[B]] : tensor<?x?xi32>, %[[C]] : tensor<?x?xi32>)
  // CHECK-SAME:     outs(%[[INIT]] : tensor<?x?xi32>)
  // CHECK-SAME:     {dimension = 1 : i64}
  // CHECK:      return %[[CONCATENATE]]
  %concat = "mhlo.concatenate"(%a, %b, %c) { dimension = 1 } : (tensor<?x?xi32>, tensor<?x?xi32>, tensor<?x?xi32>) -> tensor<?x?xi32>
  func.return %concat : tensor<?x?xi32>
}

// CHECK-LABEL: @concatenate_with_static_info
// CHECK-SAME:  %[[A:.*]]: tensor<?x32xi32>, %[[B:.*]]: tensor<64x16xi32>, %[[C:.*]]: tensor<?x?xi32>
func.func @concatenate_with_static_info(%a: tensor<?x32xi32>, %b: tensor<64x16xi32>, %c: tensor<?x?xi32>) -> tensor<64x?xi32> {
  // CHECK-DAG:  %[[C1:.*]] = arith.constant 1
  // CHECK-DAG:  %[[C48:.*]] = arith.constant 48
  // CHECK-DAG:  %[[CONCAT_DIM_C:.*]] = tensor.dim %[[C]], %[[C1]]
  // CHECK-DAG:  %[[CONCAT_DIM_SUM:.*]] = arith.addi %[[CONCAT_DIM_C]], %[[C48]]
  // CHECK-DAG:  %[[INIT:.*]] = linalg.init_tensor [64, %[[CONCAT_DIM_SUM]]]
  // CHECK:      %[[CONCAT:.*]] = thlo.concatenate
  // CHECK-SAME:     ins(%[[A]] : tensor<?x32xi32>, %[[B]] : tensor<64x16xi32>, %[[C]] : tensor<?x?xi32>)
  // CHECK-SAME:     outs(%[[INIT]] : tensor<64x?xi32>)
  // CHECK-SAME:     {dimension = 1 : i64}
  // CHECK:      return %[[CONCAT]]
  %concat = "mhlo.concatenate"(%a, %b, %c) { dimension = 1 } : (tensor<?x32xi32>, tensor<64x16xi32>, tensor<?x?xi32>) -> tensor<64x?xi32>
  func.return %concat : tensor<64x?xi32>
}

func.func @simple_gather(%operand : tensor<3x3xf32>,
                         %indices: tensor<3x2xi64>) -> tensor<3xf32> {
  %0 = "mhlo.gather"(%operand, %indices) {
    dimension_numbers = #mhlo.gather<
      collapsed_slice_dims = [0, 1],
      index_vector_dim = 1,
      offset_dims = [],
      start_index_map = [0, 1]
    >,
    indices_are_sorted = false,
    slice_sizes = dense<[1, 1]> : tensor<2xi64>
  } : (tensor<3x3xf32>, tensor<3x2xi64>) -> tensor<3xf32>
  func.return %0 : tensor<3xf32>
}

// CHECK-LABEL: @simple_gather
//       CHECK: %[[INIT:.*]] = linalg.init_tensor [3] : tensor<3xf32>
//       CHECK: %[[GATHER:.*]] = thlo.gather
//  CHECK-SAME:   ins(%arg0 : tensor<3x3xf32>, %arg1 : tensor<3x2xi64>)
//  CHECK-SAME:   outs(%[[INIT]] : tensor<3xf32>)
//       CHECK: return %[[GATHER]]

func.func @unsupported_gather(%operand: tensor<3x3xf32>,
                              %indices: tensor<3x2xi64>) -> tensor<3xf32> {
  %0 = "mhlo.gather"(%operand, %indices) {
    dimension_numbers = #mhlo.gather<
      collapsed_slice_dims = [0, 1],
      index_vector_dim = 1,
      offset_dims = [],
      start_index_map = [1, 0]
    >,
    indices_are_sorted = false,
    slice_sizes = dense<[1, 1]> : tensor<2xi64>
  } : (tensor<3x3xf32>, tensor<3x2xi64>) -> tensor<3xf32>
  func.return %0 : tensor<3xf32>
}

// CHECK-LABEL: @unsupported_gather
//       CHECK: mhlo.gather

func.func @simple_scatter(%dst: tensor<3xi32>, %indices: tensor<1x1xi32>,
                          %update: tensor<1xi32>) -> tensor<3xi32> {
  %0 = "mhlo.scatter"(%dst, %indices, %update) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    %sum = mhlo.add %arg3, %arg4 : tensor<i32>
    "mhlo.return"(%sum) : (tensor<i32>) -> ()
  }) {
    scatter_dimension_numbers = #mhlo.scatter<
      update_window_dims = [],
      inserted_window_dims = [0],
      scatter_dims_to_operand_dims = [0],
      index_vector_dim = 1,
    >,
    unique_indices = false,
    indices_are_sorted = false
  } : (tensor<3xi32>, tensor<1x1xi32>, tensor<1xi32>) -> tensor<3xi32>
  func.return %0 : tensor<3xi32>
}

// CHECK-LABEL: @simple_scatter
// CHECK-SAME: (%[[DST:.*]]: tensor<3xi32>, %[[INDICES:.*]]: tensor<1x1xi32>,
// CHECK-SAME:  %[[UPDATE:.*]]: tensor<1xi32>)
//       CHECK: thlo.scatter ins(%[[INDICES]] : tensor<1x1xi32>,
//  CHECK-SAME:                    %[[UPDATE]] : tensor<1xi32>)
//  CHECK-SAME:                outs(%[[DST]] : tensor<3xi32>)

func.func @scatter_wrong_update(%arg0: tensor<3xi32>, %arg1: tensor<1x1xi32>,
                          %arg2: tensor<1xi32>) -> tensor<3xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    %sum = mhlo.subtract %arg3, %arg4 : tensor<i32>
    "mhlo.return"(%sum) : (tensor<i32>) -> ()
  }) {
    scatter_dimension_numbers = #mhlo.scatter<
      update_window_dims = [],
      inserted_window_dims = [0],
      scatter_dims_to_operand_dims = [0],
      index_vector_dim = 1,
    >,
    unique_indices = false,
    indices_are_sorted = false
  } : (tensor<3xi32>, tensor<1x1xi32>, tensor<1xi32>) -> tensor<3xi32>
  func.return %0 : tensor<3xi32>
}

// CHECK-LABEL: @scatter_wrong_update
//       CHECK: mhlo.scatter

func.func @scatter_wrong_index_vector_dim(
              %arg0: tensor<3xi32>,
              %arg1: tensor<1xi32>,
              %arg2: tensor<1xi32>) -> tensor<3xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    %sum = mhlo.add %arg3, %arg4 : tensor<i32>
    "mhlo.return"(%sum) : (tensor<i32>) -> ()
  }) {
    scatter_dimension_numbers = #mhlo.scatter<
      update_window_dims = [],
      inserted_window_dims = [0],
      scatter_dims_to_operand_dims = [0],
      index_vector_dim = 1,
    >,
    unique_indices = false,
    indices_are_sorted = false
  } : (tensor<3xi32>, tensor<1xi32>, tensor<1xi32>) -> tensor<3xi32>
  func.return %0 : tensor<3xi32>
}

// CHECK-LABEL: @scatter_wrong_index_vector_dim
//       CHECK: mhlo.scatter

func.func @scatter_wrong_dims(%arg0: tensor<3xi32>, %arg1: tensor<1x1xi32>,
                          %arg2: tensor<3x1xi32>) -> tensor<3xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    %sum = mhlo.add %arg3, %arg4 : tensor<i32>
    "mhlo.return"(%sum) : (tensor<i32>) -> ()
  }) {
    scatter_dimension_numbers = #mhlo.scatter<
      update_window_dims = [0],
      inserted_window_dims = [],
      scatter_dims_to_operand_dims = [0],
      index_vector_dim = 1,
    >,
    unique_indices = false,
    indices_are_sorted = false
  } : (tensor<3xi32>, tensor<1x1xi32>, tensor<3x1xi32>) -> tensor<3xi32>
  func.return %0 : tensor<3xi32>
}

// CHECK-LABEL: @scatter_wrong_dims
//       CHECK: mhlo.scatter
