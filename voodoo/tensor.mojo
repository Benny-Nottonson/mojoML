from .node import Node
from .graph import Graph
from .utils import Vector
from .constants import MEMORY_POOL_SIZE
from .operator_codes import (
    add_code,
    sub_code,
    mul_code,
    div_code,
    pow_code,
)


struct Tensor[is_static: Bool = True, is_single: Bool = False]:
    var graph: Graph
    var node: Node

    fn __init__(
        inout self,
        shape: DynamicVector[Int],
    ) raises:
        let _shape = Vector[Int]()
        for i in range(len(shape)):
            _shape.push_back(shape[i])

        self.__init__(_shape)

    fn __init__(
        inout self,
        shape: Vector[Int],
    ) raises:
        self.graph = Graph()
        self.node = self.graph.node[False](
            shape, is_static, is_single, -1, Vector[Int]()
        )

    fn __copyinit__(inout self, other: Self):
        self.graph = other.graph
        self.node = other.node

    fn load_tensor_for_binary_op(self, other: Tensor) raises -> Tensor[False, False]:
        let self_static_or_single = (
            self.node.is_static or self.node.is_single_ptr.load()
        )
        let other_static_or_single = (
            other.node.is_static or other.node.is_single_ptr.load()
        )

        var new_tensor = Tensor[False, False](
            shape=self.node.shape.copy(),
        )

        if self_static_or_single:
            new_tensor.graph = other.graph
            fuse_graphs(new_tensor.graph, self.graph)
        elif other_static_or_single:
            new_tensor.graph = self.graph
            fuse_graphs(new_tensor.graph, other.graph)
        else:
            let self_nodes_len = self.graph.nodes.len.load()
            let other_nodes_len = other.graph.nodes.len.load()

            if self_nodes_len >= other_nodes_len:
                new_tensor.graph = self.graph
                fuse_graphs(new_tensor.graph, other.graph, True)
            else:
                new_tensor.graph = other.graph
                fuse_graphs(new_tensor.graph, self.graph, True)

        return new_tensor

    fn load_tensor_for_unary_op(self) raises -> Tensor[False, False]:
        let self_static_or_single = (
            self.node.is_static or self.node.is_single_ptr.load()
        )

        var new_tensor = Tensor[False, False](
            shape=self.node.shape.copy(),
        )

        if self_static_or_single:
            fuse_graphs(new_tensor.graph, self.graph)

        elif not self_static_or_single:
            new_tensor.graph = self.graph

        return new_tensor

    fn print(self, accuracy: Int = 6) raises:
        if not self.node.computed_ptr.load():
            _ = self.forward()
        self.node.print(accuracy)

    fn print_memory_pool_manager(self) raises:
        self.graph.print_memory_pool_manager()

    fn print_graph(self) raises:
        if not self.node.computed_ptr.load():
            _ = self.forward()
        self.graph.print()

    @always_inline("nodebug")
    fn initialize[
        initialization_function: String, val: Float32 = 0, val2: Float32 = 0
    ](self) raises -> Tensor[is_static, is_single]:
        self.node.initialize[initialization_function, val, val2]()
        return self

    @always_inline("nodebug")
    fn initialize(
        self, data: DTypePointer[DType.float32]
    ) raises -> Tensor[is_static, is_single]:
        self.node.initialize(data)
        return self

    @always_inline("nodebug")
    fn fill(self, val: Float32) -> Self:
        self.node.fill(val)
        return self

    @always_inline("nodebug")
    fn fill_incr(self) raises -> Self:
        self.node.fill_incr()
        return self

    @always_inline("nodebug")
    fn grad_fill_incr(self) raises -> Self:
        self.node.grad_fill_incr()
        return self

    @always_inline("nodebug")
    fn requires_grad(inout self) raises -> Self:
        self.node.requires_grad = True
        self.node.is_static = True
        self.node.computed_ptr.store(True)
        return self

    @always_inline("nodebug")
    fn static(inout self) raises -> Self:
        _ = self.forward()
        self.node.is_static = True
        return self

    @always_inline("nodebug")
    fn dynamic(inout self) raises -> Self:
        self.node.is_static = False
        self.node.is_single_ptr.store(True)
        _ = self.forward()
        return self

    @always_inline("nodebug")
    fn store(self, idx: Int, val: Float32):
        self.node.data.load().store(idx, val)

    @always_inline("nodebug")
    fn free(inout self) raises:
        self.graph.free()
        self.node.free()

    @always_inline("nodebug")
    fn clear(self, reset_static_nodes: Bool = False) raises:
        self.graph.clear(reset_static_nodes)

    @always_inline("nodebug")
    fn forward(self, keep_forward_order: Bool = False) raises -> Self:
        _ = self.graph.forward(self.node, keep_forward_order)
        return self

    @always_inline("nodebug")
    fn forward_static(inout self) raises -> Self:
        _ = self.graph.forward_static(self.node)
        return self

    @always_inline("nodebug")
    fn backward(self) raises:
        if not self.node.computed_ptr.load():
            _ = self.forward()
        self.graph.backward(self.node)

    @always_inline("nodebug")
    fn optimize[type: String = "sgd", lr: Float32 = 0.001](self) raises:
        self.graph.optimizer_step[type, lr]()

    @always_inline("nodebug")
    fn __getitem__(self, idx: Int) raises -> Float32:
        if not self.node.computed_ptr.load():
            _ = self.forward()
        return self.node.data.load().load(idx)

    @always_inline("nodebug")
    fn __setitem__(self, idx: Int, val: Float32) raises:
        self.node.data.load().store(idx, val)

    @always_inline("nodebug")
    fn capacity(self) raises -> Int:
        return self.node.cap

    @always_inline("nodebug")
    fn copy(self) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.copy(self.node)
        return new_tensor

    @always_inline("nodebug")
    fn dropout[
        dropout_rate: Float32, noise_shape: DynamicVector[Int]
    ](self) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.dropout(self.node, dropout_rate, noise_shape)
        return new_tensor

    @always_inline("nodebug")
    fn _magic_arithmetic_generic[
        operation_code: Int
    ](self, other: Tensor) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_binary_op(other)
        new_tensor.node = new_tensor.graph.arithmetic_general[operation_code](
            self.node, other.node
        )
        return new_tensor

    @always_inline("nodebug")
    fn __eq__(self, other: Tensor) raises -> Bool:
        var new_tensor = self.load_tensor_for_binary_op(other)
        new_tensor.node = new_tensor.graph.arithmetic_general[add_code](
            self.node, other.node
        )
        return new_tensor.node.is_zero()

    @always_inline("nodebug")
    fn __add__(self, other: Tensor) raises -> Tensor[False, False]:
        return self._magic_arithmetic_generic[add_code](other)

    @always_inline("nodebug")
    fn __sub__(self, other: Tensor) raises -> Tensor[False, False]:
        return self._magic_arithmetic_generic[sub_code](other)

    @always_inline("nodebug")
    fn __mul__(self, other: Tensor) raises -> Tensor[False, False]:
        return self._magic_arithmetic_generic[mul_code](other)

    @always_inline("nodebug")
    fn __truediv__(self, other: Tensor) raises -> Tensor[False, False]:
        return self._magic_arithmetic_generic[div_code](other)

    @always_inline("nodebug")
    fn __pow__(self, other: Tensor) raises -> Tensor[False, False]:
        return self._magic_arithmetic_generic[pow_code](other)

    @always_inline("nodebug")
    fn __matmul__(self, other: Tensor) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_binary_op(other)
        new_tensor.node = new_tensor.graph.mmul(self.node, other.node)
        return new_tensor

    @always_inline("nodebug")
    fn __radd__(self, other: Tensor) raises -> Tensor[False, False]:
        return self.__add__(other)

    @always_inline("nodebug")
    fn __rsub__(self, other: Tensor) raises -> Tensor[False, False]:
        return self.__sub__(other)

    @always_inline("nodebug")
    fn __rmul__(self, other: Tensor) raises -> Tensor[False, False]:
        return self.__mul__(other)

    @always_inline("nodebug")
    fn __rtruediv__(self, other: Tensor) raises -> Tensor[False, False]:
        return self.__truediv__(other)

    @always_inline("nodebug")
    fn __rpow__(self, other: Tensor) raises -> Tensor[False, False]:
        return self.__pow__(other)

    @always_inline("nodebug")
    fn __rmatmul__(self, other: Tensor) raises -> Tensor[False, False]:
        return self.__matmul__(other)

    @always_inline("nodebug")
    fn __iadd__(inout self, other: Tensor) raises:
        self.node = self.__add__(other).node

    @always_inline("nodebug")
    fn __isub__(inout self, other: Tensor) raises:
        self.node = self.__sub__(other).node

    @always_inline("nodebug")
    fn __imul__(inout self, other: Tensor) raises:
        self.node = self.__mul__(other).node

    @always_inline("nodebug")
    fn __itruediv__(inout self, other: Tensor) raises:
        self.node = self.__truediv__(other).node

    @always_inline("nodebug")
    fn __ipow__(inout self, other: Tensor) raises:
        self.node = self.__pow__(other).node

    @always_inline("nodebug")
    fn __imatmul__(inout self, other: Tensor) raises:
        self.node = self.__matmul__(other).node

    @always_inline("nodebug")
    fn _prep_scalar_tensor(self, number: Float32) raises -> Tensor[False, True]:
        let new_tensor = Tensor[False, True](
            shape=self.node.shape.copy(),
        ).fill(number)
        new_tensor.node.computed_ptr.store(True)
        return new_tensor

    @always_inline("nodebug")
    fn __add__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__add__(self._prep_scalar_tensor(number))

    @always_inline("nodebug")
    fn __sub__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__sub__(self._prep_scalar_tensor(number))

    @always_inline("nodebug")
    fn __mul__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__mul__(self._prep_scalar_tensor(number))

    @always_inline("nodebug")
    fn __truediv__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__truediv__(self._prep_scalar_tensor(number))

    @always_inline("nodebug")
    fn __pow__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__pow__(self._prep_scalar_tensor(number))

    @always_inline("nodebug")
    fn __radd__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__add__(number)

    @always_inline("nodebug")
    fn __rsub__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__sub__(number)

    @always_inline("nodebug")
    fn __rmul__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__mul__(number)

    @always_inline("nodebug")
    fn __rtruediv__(self, number: Float32) raises -> Tensor[False, False]:
        return self.__truediv__(number)

    @always_inline("nodebug")
    fn __rpow__(self, number: Float32) raises -> Tensor[False, False]:
        let other = Tensor[False, False](
            self.node.shape.copy(),
        ).fill(number)
        other.node.is_single_ptr.store(True)
        other.node.computed_ptr.store(True)
        return other.__pow__(self)

    @always_inline("nodebug")
    fn __len__(self) raises -> Int:
        return self.capacity()

    @always_inline("nodebug")
    fn reshape(self, shape: Vector[Int]) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.reshape(self.node, shape)
        return new_tensor

    @always_inline("nodebug")
    fn flatten(self) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        let shape = Vector[Int]()
        let dims = self.node.shape.len.load()
        shape.push_back(self.node.shape.load(0))
        for i in range(1, dims):
            shape.store(0, shape.load(0) * self.node.shape.load(i))
        new_tensor.node = new_tensor.graph.reshape(self.node, shape)
        return new_tensor

    @always_inline("nodebug")
    fn transp(self) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.transp(self.node)
        return new_tensor

    @always_inline("nodebug")
    fn sum(self) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.sum(self.node)
        return new_tensor

    @always_inline("nodebug")
    fn compute_function[operator_id: Int](self) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.function_general[operator_id](self.node)
        return new_tensor

    @always_inline("nodebug")
    fn compute_loss[
        operator_id: Int
    ](self, other: Tensor) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_binary_op(other)
        new_tensor.node = new_tensor.graph.loss_general[operator_id](
            self.node, other.node
        )
        return new_tensor

    @always_inline("nodebug")
    fn compute_loss[
        operator_name: String
    ](self, other: Tensor) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_binary_op(other)
        new_tensor.node = new_tensor.graph.loss_general[get_loss_code[operator_name]()](
            self.node, other.node
        )
        return new_tensor

    @always_inline("nodebug")
    fn compute_activation[
        operator_id: Int, arg1: Float32 = 0.0
    ](self) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.activation_general[operator_id, arg1](
            self.node
        )
        return new_tensor

    @always_inline("nodebug")
    fn compute_activation[
        operator_name: String, arg1: Float32 = 0.0
    ](self) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.activation_general[
            get_activation_code[operator_name](), arg1
        ](self.node)
        return new_tensor

    @always_inline("nodebug")
    fn conv_1d(
        self, other: Tensor, padding: Int, stride: Int
    ) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_binary_op(other)
        new_tensor.node = new_tensor.graph.conv_1d(
            self.node, other.node, padding, stride
        )
        return new_tensor

    @always_inline("nodebug")
    fn conv_2d(
        self, other: Tensor, padding: StaticIntTuple[2], stride: StaticIntTuple[2]
    ) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_binary_op(other)
        new_tensor.node = new_tensor.graph.conv_2d(
            self.node, other.node, padding, stride
        )
        return new_tensor

    @always_inline("nodebug")
    fn maxpool_1d(
        self, kernel_size: Int, stride: Int, padding: Int
    ) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.maxpool_1d(
            self.node, kernel_size, stride, padding
        )
        return new_tensor

    @always_inline("nodebug")
    fn maxpool_2d(
        self, kernel_size: StaticIntTuple[2], stride: Int, padding: Int
    ) raises -> Tensor[False, False]:
        var new_tensor = self.load_tensor_for_unary_op()
        new_tensor.node = new_tensor.graph.maxpool_2d(
            self.node, kernel_size, stride, padding
        )
        return new_tensor


fn fuse_graphs(
    graph_ptr: Graph,
    other_graph_ptr: Graph,
    remove_other: Bool = False,
) raises:
    let num_nodes = graph_ptr.nodes.len.load()
    let memory_pool_len = graph_ptr.memory_pool.len.load()
    let other_graph = other_graph_ptr

    for i in range(other_graph.nodes.len.load()):
        let node_ptr = other_graph.nodes.load(i)
        node_ptr.store_id(node_ptr.load_id() + num_nodes)
        for j in range(node_ptr.children.len.load()):
            node_ptr.children.store(j, node_ptr.children.load(j) + num_nodes)
        for j in range(node_ptr.parents.len.load()):
            node_ptr.parents.store(j, node_ptr.parents.load(j) + num_nodes)
        node_ptr.data_id.store(node_ptr.data_id.load() + memory_pool_len)
        graph_ptr.nodes.push_back(node_ptr)

    for i in range(other_graph.memory_pool.len.load()):
        graph_ptr.memory_pool.push_back(other_graph.memory_pool.load(i))

    for i in range(MEMORY_POOL_SIZE):
        for j in range(other_graph.memory_pool_manager.load(i).len.load()):
            graph_ptr.memory_pool_manager.load(i).push_back(
                other_graph.memory_pool_manager.load(i).load(j) + memory_pool_len
            )

    for i in range(graph_ptr.free_node_ids.len.load()):
        graph_ptr.free_node_ids.push_back(other_graph.free_node_ids.load(i) + num_nodes)

    for i in range(graph_ptr.free_data_ids.len.load()):
        graph_ptr.free_data_ids.push_back(
            other_graph.free_data_ids.load(i) + memory_pool_len
        )

    if remove_other:
        other_graph.nodes.free()
        other_graph.nodes.free()
        other_graph.memory_pool.free()
        other_graph.memory_pool.free()

        @unroll
        for i in range(MEMORY_POOL_SIZE):
            other_graph.memory_pool_manager.load(i).free()
        other_graph.memory_pool_manager.free()
        other_graph.free_node_ids.free()
        other_graph.free_node_ids.free()
        other_graph.free_data_ids.free()
        other_graph.free_data_ids.free()
        other_graph.last_node_id.free()
        other_graph.kernels.free()
        other_graph.forward_order.free()
